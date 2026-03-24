import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { createClient } from '@supabase/supabase-js'
import type { FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'

type AppTab = 'papers' | 'uploads' | 'user'

type Paper = {
  id: string
  created_at: string
  title: string
  storage_path: string
  uploaded_by: string
  content_type: string | null
  upload_batch_id: string | null
  school_name: string | null
  grade: number | null
  course_name: string | null
}

type CatalogRow = { id: string; name: string }

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string | undefined
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY as
  | string
  | undefined
const isConfigured = Boolean(SUPABASE_URL && SUPABASE_ANON_KEY)

const supabase = isConfigured
  ? createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!)
  : null

const PAPERS_TABLE = 'papers'
const SCHOOLS_TABLE = 'schools'
const COURSES_TABLE = 'courses'
const BUCKET = 'exam-papers'
const ALLOWED_EXTENSIONS = new Set(['pdf', 'png', 'jpg', 'jpeg'])
const GRADES = [9, 10, 11, 12]

function toMeta(paper: Paper) {
  const parts: string[] = []
  if (paper.school_name?.trim()) parts.push(paper.school_name.trim())
  if (paper.grade) parts.push(`Grade ${paper.grade}`)
  if (paper.course_name?.trim()) parts.push(paper.course_name.trim())
  return parts.join(' · ')
}

function groupPapers(papers: Paper[]) {
  const byBatch = new Map<string, Paper[]>()
  const singles: Paper[] = []
  for (const p of papers) {
    if (p.upload_batch_id) {
      const list = byBatch.get(p.upload_batch_id) ?? []
      list.push(p)
      byBatch.set(p.upload_batch_id, list)
    } else {
      singles.push(p)
    }
  }
  const groups: Paper[][] = []
  for (const list of byBatch.values()) {
    list.sort(
      (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
    )
    groups.push(list)
  }
  singles.forEach((x) => groups.push([x]))
  groups.sort(
    (a, b) =>
      new Date(b[b.length - 1].created_at).getTime() -
      new Date(a[a.length - 1].created_at).getTime(),
  )
  return groups
}

function App() {
  if (!isConfigured || !supabase) {
    return (
      <div className="setup-card">
        <h1>Acadex Web Setup</h1>
        <p>
          Create `web_app/.env.local` and add `VITE_SUPABASE_URL` and
          `VITE_SUPABASE_ANON_KEY`.
        </p>
      </div>
    )
  }
  return <ConfiguredApp />
}

function ConfiguredApp() {
  const [session, setSession] = useState<Session | null>(null)
  const [tab, setTab] = useState<AppTab>('papers')

  useEffect(() => {
    supabase!.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase!.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  if (!session) return <AuthScreen />

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <h2>Acadex</h2>
        <button className={tab === 'papers' ? 'active' : ''} onClick={() => setTab('papers')}>
          Papers
        </button>
        <button className={tab === 'uploads' ? 'active' : ''} onClick={() => setTab('uploads')}>
          My Uploads
        </button>
        <button className={tab === 'user' ? 'active' : ''} onClick={() => setTab('user')}>
          User
        </button>
      </aside>
      <main className="content">
        {tab === 'papers' && <PapersTab />}
        {tab === 'uploads' && <UploadsTab userId={session.user.id} />}
        {tab === 'user' && <UserTab email={session.user.email ?? ''} />}
      </main>
    </div>
  )
}

function AuthScreen() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [signUp, setSignUp] = useState(false)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!email.trim() || !password) {
      setMessage('Please enter email and password.')
      return
    }
    setBusy(true)
    setMessage('')
    try {
      if (signUp) {
        const { data, error } = await supabase!.auth.signUp({ email, password })
        if (error) throw error
        if (!data.session) {
          setMessage('Sign-up ok. Confirm email, or disable confirmation in Supabase for dev.')
        }
      } else {
        const { error } = await supabase!.auth.signInWithPassword({ email, password })
        if (error) throw error
      }
    } catch (err) {
      setMessage(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth-wrap">
      <form className="panel" onSubmit={submit}>
        <h1>{signUp ? 'Sign up' : 'Sign in'}</h1>
        <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
        <input
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          type="password"
          placeholder="Password"
        />
        <button disabled={busy}>{busy ? 'Loading...' : signUp ? 'Create account' : 'Sign in'}</button>
        <button type="button" className="secondary" onClick={() => setSignUp((v) => !v)}>
          {signUp ? 'Have account? Sign in' : 'Need account? Sign up'}
        </button>
        {message && <p className="msg">{message}</p>}
      </form>
    </div>
  )
}

function PapersTab() {
  const [papers, setPapers] = useState<Paper[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedGroup, setSelectedGroup] = useState<Paper[] | null>(null)
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [query, setQuery] = useState('')
  const [selectedSchool, setSelectedSchool] = useState('')
  const [selectedGrade, setSelectedGrade] = useState('')
  const [selectedCourse, setSelectedCourse] = useState('')
  const [showFilters, setShowFilters] = useState(false)
  const searchAreaRef = useRef<HTMLDivElement | null>(null)

  async function load() {
    setLoading(true)
    setError('')
    const { data, error: err } = await supabase!
      .from(PAPERS_TABLE)
      .select('*')
      .order('created_at', { ascending: false })
    if (err) {
      setError(err.message)
      setLoading(false)
      return
    }
    setPapers((data as Paper[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load()
  }, [])

  const schoolOptions = useMemo(
    () =>
      Array.from(
        new Set(papers.map((p) => p.school_name?.trim()).filter((x): x is string => Boolean(x))),
      ).sort((a, b) => a.localeCompare(b)),
    [papers],
  )

  const gradeOptions = useMemo(
    () =>
      Array.from(new Set(papers.map((p) => p.grade).filter((x): x is number => typeof x === 'number'))).sort(
        (a, b) => a - b,
      ),
    [papers],
  )

  const courseOptions = useMemo(
    () =>
      Array.from(
        new Set(papers.map((p) => p.course_name?.trim()).filter((x): x is string => Boolean(x))),
      ).sort((a, b) => a.localeCompare(b)),
    [papers],
  )

  const filteredPapers = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    return papers.filter((p) => {
      const matchesSchool = !selectedSchool || (p.school_name ?? '') === selectedSchool
      const matchesGrade = !selectedGrade || String(p.grade ?? '') === selectedGrade
      const matchesCourse = !selectedCourse || (p.course_name ?? '') === selectedCourse
      if (!matchesSchool || !matchesGrade || !matchesCourse) return false
      if (!normalized) return true

      const haystack = [p.title, p.school_name ?? '', p.course_name ?? '', toMeta(p)].join(' ').toLowerCase()
      return haystack.includes(normalized)
    })
  }, [papers, query, selectedSchool, selectedGrade, selectedCourse])

  const groups = useMemo(() => groupPapers(filteredPapers), [filteredPapers])
  const isAllPapersView =
    query.trim().length === 0 && !selectedSchool && !selectedGrade && !selectedCourse

  return (
    <section className="panel">
      <div className="row">
        <h1>Papers</h1>
      </div>
      <div
        ref={searchAreaRef}
        className="search-area"
        onFocusCapture={() => setShowFilters(true)}
        onBlurCapture={(e) => {
          const next = e.relatedTarget as Node | null
          if (!next || !searchAreaRef.current?.contains(next)) {
            setShowFilters(false)
          }
        }}
      >
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search papers..."
        />
        {showFilters && (
          <div className="filter-row">
            <select value={selectedSchool} onChange={(e) => setSelectedSchool(e.target.value)}>
              <option value="">All schools</option>
              {schoolOptions.map((school) => (
                <option key={school} value={school}>
                  {school}
                </option>
              ))}
            </select>
            <select value={selectedGrade} onChange={(e) => setSelectedGrade(e.target.value)}>
              <option value="">All grades</option>
              {gradeOptions.map((grade) => (
                <option key={grade} value={String(grade)}>
                  Grade {grade}
                </option>
              ))}
            </select>
            <select value={selectedCourse} onChange={(e) => setSelectedCourse(e.target.value)}>
              <option value="">All courses</option>
              {courseOptions.map((course) => (
                <option key={course} value={course}>
                  {course}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>
      <p className="subtitle">{isAllPapersView ? 'All Papers' : 'Selected Papers'}</p>
      {error && <p className="msg">{error}</p>}
      {loading ? (
        <p>Loading...</p>
      ) : groups.length === 0 ? (
        <p>No papers yet.</p>
      ) : (
        <div className="list">
          {groups.map((group) => {
            const opener = group[0]
            const latest = group[group.length - 1]
            const title =
              group.length > 1
                ? `${opener.title.replace(/\s\(\d+\)$/, '')} (${group.length} files)`
                : opener.title
            return (
              <button
                key={opener.id}
                className="card"
                onClick={() => {
                  setSelectedGroup(group)
                  setSelectedIndex(0)
                }}
              >
                <strong>{title}</strong>
                <span>{toMeta(opener)}</span>
                <span>{new Date(latest.created_at).toLocaleString()}</span>
              </button>
            )
          })}
        </div>
      )}
      {selectedGroup && (
        <PreviewModal
          papers={selectedGroup}
          index={selectedIndex}
          setIndex={setSelectedIndex}
          onClose={() => setSelectedGroup(null)}
        />
      )}
    </section>
  )
}

function UploadsTab({ userId }: { userId: string }) {
  const [papers, setPapers] = useState<Paper[]>([])
  const [schools, setSchools] = useState<CatalogRow[]>([])
  const [courses, setCourses] = useState<CatalogRow[]>([])
  const [schoolId, setSchoolId] = useState('')
  const [courseId, setCourseId] = useState('')
  const [grade, setGrade] = useState(10)
  const [title, setTitle] = useState('')
  const [selectedFiles, setSelectedFiles] = useState<FileList | null>(null)
  const [uploading, setUploading] = useState(false)
  const [message, setMessage] = useState('')
  const [newCatalogType, setNewCatalogType] = useState<'school' | 'course' | null>(null)
  const [newCatalogName, setNewCatalogName] = useState('')
  const [catalogBusy, setCatalogBusy] = useState(false)
  const [pendingDeleteGroup, setPendingDeleteGroup] = useState<Paper[] | null>(null)
  const [creatingUpload, setCreatingUpload] = useState(false)

  const loadMine = useCallback(async () => {
    const { data, error } = await supabase!
      .from(PAPERS_TABLE)
      .select('*')
      .eq('uploaded_by', userId)
      .order('created_at', { ascending: false })
    if (error) {
      setMessage(error.message)
      return
    }
    setPapers((data as Paper[]) ?? [])
  }, [userId])

  const loadCatalog = useCallback(async () => {
    const [schoolRes, courseRes] = await Promise.all([
      supabase!.from(SCHOOLS_TABLE).select('id,name').order('name'),
      supabase!.from(COURSES_TABLE).select('id,name').order('name'),
    ])
    if (!schoolRes.error) setSchools((schoolRes.data as CatalogRow[]) ?? [])
    if (!courseRes.error) setCourses((courseRes.data as CatalogRow[]) ?? [])
  }, [])

  useEffect(() => {
    void loadMine()
    void loadCatalog()
  }, [loadMine, loadCatalog])

  function openCatalogModal(type: 'school' | 'course') {
    setNewCatalogType(type)
    setNewCatalogName('')
  }

  async function createCatalog() {
    if (!newCatalogType) return
    const name = newCatalogName.trim()
    if (!name) {
      setMessage('Please enter a valid name.')
      return
    }
    setCatalogBusy(true)
    const table = newCatalogType === 'school' ? SCHOOLS_TABLE : COURSES_TABLE
    const { error } = await supabase!.from(table).insert({ name })
    setCatalogBusy(false)
    if (error) {
      setMessage(error.message)
      return
    }
    await loadCatalog()
    setNewCatalogType(null)
    setNewCatalogName('')
  }

  async function onUpload(files: FileList | null) {
    if (!files?.length) return
    if (!schoolId || !courseId || !GRADES.includes(grade) || !title.trim()) {
      setMessage('Please fill School, Course, Grade, and Title.')
      return
    }
    setUploading(true)
    setMessage('')
    const batchId = files.length > 1 ? crypto.randomUUID() : null
    const schoolName = schools.find((x) => x.id === schoolId)?.name ?? ''
    const courseName = courses.find((x) => x.id === courseId)?.name ?? ''

    try {
      for (let i = 0; i < files.length; i += 1) {
        const file = files[i]
        const ext = file.name.split('.').pop()?.toLowerCase() ?? ''
        if (!ALLOWED_EXTENSIONS.has(ext)) {
          throw new Error(`Unsupported file: ${file.name}`)
        }
        const objectPath = `${userId}/${crypto.randomUUID()}.${ext}`
        const { error: uploadErr } = await supabase!.storage.from(BUCKET).upload(objectPath, file, {
          contentType: file.type || 'application/octet-stream',
          upsert: false,
        })
        if (uploadErr) throw uploadErr

        const computedTitle =
          files.length === 1
            ? title.trim()
            : `${title.trim()} (${i + 1})`

        const row = {
          title: computedTitle,
          storage_path: objectPath,
          uploaded_by: userId,
          content_type: file.type || 'application/octet-stream',
          school_id: schoolId,
          school_name: schoolName,
          grade,
          course_id: courseId,
          course_name: courseName,
          upload_batch_id: batchId,
        }
        const { error: insertErr } = await supabase!.from(PAPERS_TABLE).insert(row)
        if (insertErr) throw insertErr
      }
      setTitle('')
      setSelectedFiles(null)
      setMessage(files.length > 1 ? `${files.length} files uploaded.` : 'File uploaded.')
      await loadMine()
    } catch (err) {
      setMessage(err instanceof Error ? err.message : String(err))
    } finally {
      setUploading(false)
    }
  }

  async function removeGroup(group: Paper[]) {
    const paths = group.map((g) => g.storage_path)
    const ids = group.map((g) => g.id)
    const storageRes = await supabase!.storage.from(BUCKET).remove(paths)
    if (storageRes.error) {
      setMessage(storageRes.error.message)
      return
    }
    const dbRes = await supabase!.from(PAPERS_TABLE).delete().in('id', ids)
    if (dbRes.error) {
      setMessage(dbRes.error.message)
      return
    }
    setPendingDeleteGroup(null)
    await loadMine()
  }

  const groups = useMemo(() => groupPapers(papers), [papers])

  return (
    <section className="panel">
      <div className="row between">
        <h1>{creatingUpload ? 'Create New Upload' : 'My Uploads'}</h1>
        {creatingUpload ? (
          <button className="secondary" onClick={() => setCreatingUpload(false)}>
            Back to My Uploads
          </button>
        ) : (
          <button onClick={() => setCreatingUpload(true)}>Create New Upload</button>
        )}
      </div>
      {message && <p className="msg">{message}</p>}
      {!creatingUpload ? (
        <div>
          <h3>Your uploads</h3>
          <div className="list">
            {groups.length === 0 ? (
              <p>Nothing uploaded yet.</p>
            ) : (
              groups.map((group) => (
                <div key={group[0].id} className="card upload-row">
                  <div className="upload-main">
                    <strong>{group.length > 1 ? `${group[0].title} (${group.length})` : group[0].title}</strong>
                    <span>{toMeta(group[0])}</span>
                  </div>
                  <button
                    className="icon-danger"
                    aria-label="Delete upload"
                    title="Delete upload"
                    onClick={() => setPendingDeleteGroup(group)}
                  >
                    🗑
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      ) : (
        <div>
          <h3>Fill required fields and upload files</h3>
          <label>
            School <span className="required">*</span>
          </label>
          <div className="row">
            <select value={schoolId} onChange={(e) => setSchoolId(e.target.value)}>
              <option value="">Choose school</option>
              {schools.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
            <button className="secondary" onClick={() => openCatalogModal('school')}>
              + New
            </button>
          </div>

          <label>
            Course <span className="required">*</span>
          </label>
          <div className="row">
            <select value={courseId} onChange={(e) => setCourseId(e.target.value)}>
              <option value="">Choose course</option>
              {courses.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <button className="secondary" onClick={() => openCatalogModal('course')}>
              + New
            </button>
          </div>

          <label>
            Grade <span className="required">*</span>
          </label>
          <select value={grade} onChange={(e) => setGrade(Number(e.target.value))}>
            {GRADES.map((g) => (
              <option key={g} value={g}>
                Grade {g}
              </option>
            ))}
          </select>

          <label>
            Title <span className="required">*</span>
          </label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Enter title" />

          <label>Choose file(s): PDF / JPG / PNG</label>
          <input
            type="file"
            multiple
            accept=".pdf,.png,.jpg,.jpeg"
            disabled={uploading}
            onChange={(e) => setSelectedFiles(e.target.files)}
          />
          <button
            disabled={uploading || !selectedFiles?.length}
            onClick={() => onUpload(selectedFiles)}
          >
            {uploading ? 'Uploading...' : 'Upload'}
          </button>
        </div>
      )}
      {newCatalogType && (
        <div className="modal-backdrop">
          <div className="modal modal-small">
            <strong>Create new {newCatalogType}</strong>
            <label>Name</label>
            <input
              autoFocus
              value={newCatalogName}
              onChange={(e) => setNewCatalogName(e.target.value)}
              placeholder={`Enter ${newCatalogType} name`}
            />
            <div className="row end">
              <button className="secondary" onClick={() => setNewCatalogType(null)}>
                Cancel
              </button>
              <button disabled={catalogBusy} onClick={createCatalog}>
                {catalogBusy ? 'Creating...' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}
      {pendingDeleteGroup && (
        <div className="modal-backdrop">
          <div className="modal modal-small">
            <strong>Delete upload?</strong>
            <p>This will remove {pendingDeleteGroup.length} file(s) from storage and database.</p>
            <div className="row end">
              <button className="secondary" onClick={() => setPendingDeleteGroup(null)}>
                Cancel
              </button>
              <button className="danger" onClick={() => removeGroup(pendingDeleteGroup)}>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

function UserTab({ email }: { email: string }) {
  return (
    <section className="panel">
      <h1>User</h1>
      <p>{email || 'Not signed in'}</p>
      <button onClick={() => supabase!.auth.signOut()}>Sign out</button>
    </section>
  )
}

function PreviewModal({
  papers,
  index,
  setIndex,
  onClose,
}: {
  papers: Paper[]
  index: number
  setIndex: (next: number) => void
  onClose: () => void
}) {
  const current = papers[index]
  const [url, setUrl] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    let mounted = true
    supabase!.storage
      .from(BUCKET)
      .createSignedUrl(current.storage_path, 60 * 10)
      .then(({ data, error: err }) => {
        if (!mounted) return
        if (err) setError(err.message)
        else setUrl(data.signedUrl)
      })
    return () => {
      mounted = false
    }
  }, [current.id, current.storage_path])

  const isPdf =
    current.content_type?.toLowerCase().includes('pdf') ||
    current.storage_path.toLowerCase().endsWith('.pdf')

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="row between">
          <strong>
            {current.title} ({index + 1}/{papers.length})
          </strong>
          <button className="secondary" onClick={onClose}>
            Close
          </button>
        </div>
        <p>{toMeta(current)}</p>
        <div className="preview">
          {error ? (
            <p className="msg">{error}</p>
          ) : !url ? (
            <p>Loading preview...</p>
          ) : isPdf ? (
            <iframe title="paper-preview" src={url} />
          ) : (
            <img src={url} alt={current.title} />
          )}
        </div>
        <div className="row center">
          <button className="secondary" disabled={index <= 0} onClick={() => setIndex(index - 1)}>
            Prev
          </button>
          <button
            className="secondary"
            disabled={index >= papers.length - 1}
            onClick={() => setIndex(index + 1)}
          >
            Next
          </button>
        </div>
      </div>
    </div>
  )
}

export default App
