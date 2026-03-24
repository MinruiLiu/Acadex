import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import type { ReactNode } from 'react'
import { createClient } from '@supabase/supabase-js'
import type { FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'

type AppTab = 'papers' | 'uploads' | 'user' | 'review' | 'messages'

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
  paper_year: number | null
  semester: string | null
  paper_version: string | null
  approval_status: 'pending' | 'approved'
}

type SystemMessage = {
  id: string
  user_id: string
  title: string
  body: string
  created_at: string
  read_at: string | null
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
const USERS_TABLE_PUBLIC = 'users'
const SYSTEM_MESSAGES_TABLE = 'system_messages'
const BUCKET = 'exam-papers'
const ALLOWED_EXTENSIONS = new Set(['pdf', 'png', 'jpg', 'jpeg'])
const GRADES = [9, 10, 11, 12]
const SEMESTERS = ['Semester 1', 'Semester 2'] as const

function displayAccountTypeLabel(raw: string | null | undefined): string {
  if (raw == null || raw === '') return 'Account'
  const k = raw.toLowerCase()
  if (k === 'student') return 'Student account'
  if (k === 'administrator') return 'Administrator account'
  return raw
}

function uploadYearChoices(): number[] {
  const y = new Date().getFullYear()
  const out: number[] = []
  for (let i = y + 1; i >= 2000; i -= 1) out.push(i)
  return out
}

function toMeta(paper: Paper) {
  const parts: string[] = []
  if (paper.school_name?.trim()) parts.push(paper.school_name.trim())
  if (paper.grade) parts.push(`Grade ${paper.grade}`)
  if (paper.course_name?.trim()) parts.push(paper.course_name.trim())
  if (paper.paper_year != null) parts.push(String(paper.paper_year))
  if (paper.semester?.trim()) parts.push(paper.semester.trim())
  if (paper.paper_version?.trim()) parts.push(paper.paper_version.trim())
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

type ToastVariant = 'default' | 'success' | 'danger'

type ShowToastFn = (text: string, variant?: ToastVariant) => void

const ToastContext = createContext<ShowToastFn | null>(null)

function useToast(): ShowToastFn {
  const ctx = useContext(ToastContext)
  if (ctx == null) {
    throw new Error('useToast must be used within ToastProvider')
  }
  return ctx
}

function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<{
    text: string
    variant: ToastVariant
    key: number
  } | null>(null)
  const [exiting, setExiting] = useState(false)
  const dismissTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const exitTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const clearDismissTimer = () => {
    if (dismissTimerRef.current != null) {
      window.clearTimeout(dismissTimerRef.current)
      dismissTimerRef.current = null
    }
  }

  const clearExitTimer = () => {
    if (exitTimerRef.current != null) {
      window.clearTimeout(exitTimerRef.current)
      exitTimerRef.current = null
    }
  }

  const clearAllTimers = () => {
    clearDismissTimer()
    clearExitTimer()
  }

  const removeToast = useCallback(() => {
    setToast(null)
    setExiting(false)
    clearAllTimers()
  }, [])

  const beginExit = useCallback(() => {
    setExiting(true)
    clearDismissTimer()
    clearExitTimer()
    exitTimerRef.current = window.setTimeout(() => {
      removeToast()
    }, 300)
  }, [removeToast])

  const scheduleAutoDismiss = useCallback(() => {
    clearDismissTimer()
    dismissTimerRef.current = window.setTimeout(() => {
      beginExit()
    }, 3000)
  }, [beginExit])

  const showToast = useCallback((text: string, variant: ToastVariant = 'default') => {
    clearAllTimers()
    setExiting(false)
    setToast((prev) => ({ text, variant, key: (prev?.key ?? 0) + 1 }))
  }, [])

  useEffect(() => {
    if (!toast || exiting) return
    scheduleAutoDismiss()
    return () => clearDismissTimer()
  }, [toast, exiting, scheduleAutoDismiss])

  const dismiss = useCallback(() => {
    beginExit()
  }, [beginExit])

  return (
    <ToastContext.Provider value={showToast}>
      {children}
      {toast ? (
        <div
          className={`app-toast app-toast--${toast.variant} ${exiting ? 'app-toast--exiting' : ''}`}
          key={toast.key}
          role="status"
        >
          <span className="app-toast-text">{toast.text}</span>
          <button type="button" className="app-toast-close" onClick={dismiss} aria-label="Dismiss">
            ×
          </button>
        </div>
      ) : null}
    </ToastContext.Provider>
  )
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
  const [accountType, setAccountType] = useState<string | null>(null)
  const [profileLoadState, setProfileLoadState] = useState<'idle' | 'loading' | 'done'>('idle')

  const isAdmin =
    profileLoadState === 'done' && accountType?.toLowerCase() === 'administrator'

  useEffect(() => {
    supabase!.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase!.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session?.user.id) {
      setAccountType(null)
      setProfileLoadState('idle')
      return
    }
    let cancelled = false
    setProfileLoadState('loading')
    void supabase!
      .from(USERS_TABLE_PUBLIC)
      .select('account_type')
      .eq('id', session.user.id)
      .maybeSingle()
      .then(({ data, error }) => {
        if (cancelled) return
        if (!error && data && typeof (data as { account_type?: string }).account_type === 'string') {
          setAccountType((data as { account_type: string }).account_type)
        } else {
          setAccountType(null)
        }
        setProfileLoadState('done')
      })
    return () => {
      cancelled = true
    }
  }, [session?.user.id])

  useEffect(() => {
    if (!isAdmin && tab === 'review') {
      setTab('papers')
    }
  }, [isAdmin, tab])

  const [hasUnreadSystemMessages, setHasUnreadSystemMessages] = useState(false)

  const refreshSystemMessageUnread = useCallback(async () => {
    if (!session?.user.id) return
    const { count, error } = await supabase!
      .from(SYSTEM_MESSAGES_TABLE)
      .select('id', { count: 'exact', head: true })
      .eq('user_id', session.user.id)
      .is('read_at', null)
    if (error) return
    setHasUnreadSystemMessages((count ?? 0) > 0)
  }, [session?.user.id])

  useEffect(() => {
    if (!session?.user.id) {
      setHasUnreadSystemMessages(false)
      return
    }
    void refreshSystemMessageUnread()
    const channel = supabase!
      .channel(`system_messages_unread_${session.user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: SYSTEM_MESSAGES_TABLE,
          filter: `user_id=eq.${session.user.id}`,
        },
        () => {
          void refreshSystemMessageUnread()
        },
      )
      .subscribe()
    return () => {
      void supabase!.removeChannel(channel)
    }
  }, [session?.user.id, refreshSystemMessageUnread])

  return (
    <ToastProvider>
      {!session ? (
        <AuthScreen />
      ) : (
        <div className="app-shell">
          <aside className="sidebar">
            <h2>Acadex</h2>
            <button className={tab === 'papers' ? 'active' : ''} onClick={() => setTab('papers')}>
              Papers
            </button>
            {isAdmin ? (
              <button className={tab === 'review' ? 'active' : ''} onClick={() => setTab('review')}>
                Review Uploads
              </button>
            ) : (
              <button className={tab === 'uploads' ? 'active' : ''} onClick={() => setTab('uploads')}>
                My Uploads
              </button>
            )}
            <button className={tab === 'messages' ? 'active' : ''} onClick={() => setTab('messages')}>
              System Messages
              {hasUnreadSystemMessages ? <span className="tab-unread-dot" aria-label="Unread messages" /> : null}
            </button>
            <button className={tab === 'user' ? 'active' : ''} onClick={() => setTab('user')}>
              User
            </button>
          </aside>
          <main className="content">
            {tab === 'papers' && <PapersTab />}
            {tab === 'uploads' && (
              <UploadsTab userId={session.user.id} skipPendingNotification={isAdmin} />
            )}
            {tab === 'review' && <ReviewUploadsTab />}
            {tab === 'messages' && (
              <SystemMessagesTab userId={session.user.id} onUnreadMayHaveChanged={refreshSystemMessageUnread} />
            )}
            {tab === 'user' && (
              <UserTab
                email={session.user.email ?? ''}
                accountType={accountType}
                profileLoading={profileLoadState !== 'done'}
                isAdmin={isAdmin}
                onGoToUploads={() => setTab('uploads')}
              />
            )}
          </main>
        </div>
      )}
    </ToastProvider>
  )
}

function AuthScreen() {
  const showToast = useToast()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [signUp, setSignUp] = useState(false)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!email.trim() || !password) {
      showToast('Please enter email and password.', 'default')
      return
    }
    setBusy(true)
    try {
      if (signUp) {
        const { data, error } = await supabase!.auth.signUp({ email, password })
        if (error) throw error
        if (!data.session) {
          showToast('Sign-up ok. Confirm email, or disable confirmation in Supabase for dev.', 'default')
        }
      } else {
        const { error } = await supabase!.auth.signInWithPassword({ email, password })
        if (error) throw error
      }
    } catch (err) {
      showToast(err instanceof Error ? err.message : String(err), 'danger')
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
      </form>
    </div>
  )
}

function PapersTab() {
  const showToast = useToast()
  const [papers, setPapers] = useState<Paper[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedGroup, setSelectedGroup] = useState<Paper[] | null>(null)
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [query, setQuery] = useState('')
  const [selectedSchool, setSelectedSchool] = useState('')
  const [selectedGrade, setSelectedGrade] = useState('')
  const [selectedCourse, setSelectedCourse] = useState('')
  const [selectedYear, setSelectedYear] = useState('')
  const [selectedSemester, setSelectedSemester] = useState('')
  const [showFilters, setShowFilters] = useState(false)
  const searchAreaRef = useRef<HTMLDivElement | null>(null)

  async function load() {
    setLoading(true)
    const { data, error: err } = await supabase!
      .from(PAPERS_TABLE)
      .select('*')
      .eq('approval_status', 'approved')
      .order('created_at', { ascending: false })
    if (err) {
      showToast(err.message, 'danger')
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

  const yearOptions = useMemo(
    () =>
      Array.from(
        new Set(papers.map((p) => p.paper_year).filter((x): x is number => typeof x === 'number')),
      ).sort((a, b) => b - a),
    [papers],
  )

  const filteredPapers = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    return papers.filter((p) => {
      const matchesSchool = !selectedSchool || (p.school_name ?? '') === selectedSchool
      const matchesGrade = !selectedGrade || String(p.grade ?? '') === selectedGrade
      const matchesCourse = !selectedCourse || (p.course_name ?? '') === selectedCourse
      const matchesYear = !selectedYear || String(p.paper_year ?? '') === selectedYear
      const matchesSemester = !selectedSemester || (p.semester ?? '') === selectedSemester
      if (!matchesSchool || !matchesGrade || !matchesCourse || !matchesYear || !matchesSemester)
        return false
      if (!normalized) return true

      const haystack = [
        p.title,
        p.school_name ?? '',
        p.course_name ?? '',
        p.paper_year != null ? String(p.paper_year) : '',
        p.semester ?? '',
        p.paper_version ?? '',
        toMeta(p),
      ]
        .join(' ')
        .toLowerCase()
      return haystack.includes(normalized)
    })
  }, [papers, query, selectedSchool, selectedGrade, selectedCourse, selectedYear, selectedSemester])

  const groups = useMemo(() => groupPapers(filteredPapers), [filteredPapers])
  const isAllPapersView =
    query.trim().length === 0 &&
    !selectedSchool &&
    !selectedGrade &&
    !selectedCourse &&
    !selectedYear &&
    !selectedSemester

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
              <option value="">All course codes</option>
              {courseOptions.map((course) => (
                <option key={course} value={course}>
                  {course}
                </option>
              ))}
            </select>
            <select value={selectedYear} onChange={(e) => setSelectedYear(e.target.value)}>
              <option value="">All years</option>
              {yearOptions.map((y) => (
                <option key={y} value={String(y)}>
                  {y}
                </option>
              ))}
            </select>
            <select value={selectedSemester} onChange={(e) => setSelectedSemester(e.target.value)}>
              <option value="">All semesters</option>
              {SEMESTERS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>
      <p className="subtitle">{isAllPapersView ? 'All Papers' : 'Selected Papers'}</p>
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

function UploadsTab({
  userId,
  skipPendingNotification,
}: {
  userId: string
  /** Administrator uploads are auto-approved; do not send "pending review" system message. */
  skipPendingNotification: boolean
}) {
  const showToast = useToast()
  const [papers, setPapers] = useState<Paper[]>([])
  const [schools, setSchools] = useState<CatalogRow[]>([])
  const [courses, setCourses] = useState<CatalogRow[]>([])
  const [schoolId, setSchoolId] = useState('')
  const [courseId, setCourseId] = useState('')
  const [grade, setGrade] = useState(10)
  const [paperYear, setPaperYear] = useState(() => new Date().getFullYear())
  const [semester, setSemester] = useState<(typeof SEMESTERS)[number]>('Semester 1')
  const [version, setVersion] = useState('')
  const [title, setTitle] = useState('')
  const [selectedFiles, setSelectedFiles] = useState<FileList | null>(null)
  const [uploading, setUploading] = useState(false)
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
      showToast(error.message, 'danger')
      return
    }
    setPapers((data as Paper[]) ?? [])
  }, [userId, showToast])

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
      showToast('Please enter a valid name.', 'default')
      return
    }
    setCatalogBusy(true)
    const table = newCatalogType === 'school' ? SCHOOLS_TABLE : COURSES_TABLE
    const { data, error } = await supabase!
      .from(table)
      .insert({ name })
      .select('id')
      .single()
    setCatalogBusy(false)
    if (error) {
      showToast(error.message, 'danger')
      return
    }
    const newId = (data as { id: string }).id
    await loadCatalog()
    if (newCatalogType === 'school') {
      setSchoolId(newId)
    } else {
      setCourseId(newId)
    }
    setNewCatalogType(null)
    setNewCatalogName('')
  }

  async function onUpload(files: FileList | null) {
    if (!files?.length) return
    if (!schoolId || !courseId || !GRADES.includes(grade) || !title.trim()) {
      showToast('Please fill School, Course code, Grade, Year, Semester, and Title.', 'default')
      return
    }
    if (!uploadYearChoices().includes(paperYear)) {
      showToast('Please choose a valid year.', 'default')
      return
    }
    if (!SEMESTERS.includes(semester)) {
      showToast('Please choose Semester 1 or Semester 2.', 'default')
      return
    }
    setUploading(true)
    const batchId = files.length > 1 ? crypto.randomUUID() : null
    const schoolName = schools.find((x) => x.id === schoolId)?.name ?? ''
    const courseName = courses.find((x) => x.id === courseId)?.name ?? ''

    const insertedIds: string[] = []
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

        const v = version.trim()
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
          paper_year: paperYear,
          semester,
          upload_batch_id: batchId,
          ...(v ? { paper_version: v } : {}),
        }
        const { data: ins, error: insertErr } = await supabase!
          .from(PAPERS_TABLE)
          .insert(row)
          .select('id')
          .single()
        if (insertErr) throw insertErr
        insertedIds.push((ins as { id: string }).id)
      }
      if (!skipPendingNotification && insertedIds.length > 0) {
        const { error: rpcErr } = await supabase!.rpc('notify_upload_pending_review', {
          p_paper_ids: insertedIds,
        })
        if (rpcErr) throw rpcErr
      }
      setTitle('')
      setSelectedFiles(null)
      setCreatingUpload(false)
      showToast(
        skipPendingNotification
          ? files.length > 1
            ? `${files.length} files published`
            : 'File published'
          : files.length > 1
            ? `${files.length} files submitted for review`
            : 'Submitted for review',
        'success',
      )
      await loadMine()
    } catch (err) {
      showToast(err instanceof Error ? err.message : String(err), 'danger')
    } finally {
      setUploading(false)
    }
  }

  async function removeGroup(group: Paper[]) {
    const paths = group.map((g) => g.storage_path)
    const ids = group.map((g) => g.id)
    const storageRes = await supabase!.storage.from(BUCKET).remove(paths)
    if (storageRes.error) {
      showToast(storageRes.error.message, 'danger')
      return
    }
    const dbRes = await supabase!.from(PAPERS_TABLE).delete().in('id', ids)
    if (dbRes.error) {
      showToast(dbRes.error.message, 'danger')
      return
    }
    setPendingDeleteGroup(null)
    await loadMine()
    showToast(group.length > 1 ? 'Files Deleted' : 'File Deleted', 'danger')
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
                    <span className="subtitle" style={{ fontSize: 12, fontWeight: 500 }}>
                      {group[0].approval_status === 'pending' ? 'Pending review' : 'Published'}
                    </span>
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
            Course code <span className="required">*</span>
          </label>
          <div className="row">
            <select value={courseId} onChange={(e) => setCourseId(e.target.value)}>
              <option value="">Choose course code</option>
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
            Year <span className="required">*</span>
          </label>
          <select value={paperYear} onChange={(e) => setPaperYear(Number(e.target.value))}>
            {uploadYearChoices().map((y) => (
              <option key={y} value={y}>
                {y}
              </option>
            ))}
          </select>

          <label>
            Semester <span className="required">*</span>
          </label>
          <select value={semester} onChange={(e) => setSemester(e.target.value as (typeof SEMESTERS)[number])}>
            {SEMESTERS.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>

          <label>Version (optional)</label>
          <input value={version} onChange={(e) => setVersion(e.target.value)} placeholder="e.g. morning" />

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
            type="button"
            className="upload-submit"
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
            <strong>Create new {newCatalogType === 'course' ? 'course code' : newCatalogType}</strong>
            <label>Name</label>
            <input
              autoFocus
              value={newCatalogName}
              onChange={(e) => setNewCatalogName(e.target.value)}
              placeholder={newCatalogType === 'course' ? 'Course code name' : `Enter ${newCatalogType} name`}
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

function SystemMessagesTab({
  userId,
  onUnreadMayHaveChanged,
}: {
  userId: string
  onUnreadMayHaveChanged?: () => void
}) {
  const showToast = useToast()
  const [rows, setRows] = useState<SystemMessage[]>([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState<SystemMessage | null>(null)
  const [pendingDeleteMessage, setPendingDeleteMessage] = useState<SystemMessage | null>(null)

  useEffect(() => {
    let cancelled = false
    async function load(opts?: { silent?: boolean }) {
      if (!opts?.silent) setLoading(true)
      const { data, error } = await supabase!
        .from(SYSTEM_MESSAGES_TABLE)
        .select('id,user_id,title,body,created_at,read_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
      if (cancelled) return
      if (error) {
        showToast(error.message, 'danger')
        setRows([])
      } else {
        setRows((data as SystemMessage[]) ?? [])
      }
      if (!opts?.silent) setLoading(false)
    }
    void load()
    const channel = supabase!
      .channel(`system_messages_${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: SYSTEM_MESSAGES_TABLE,
          filter: `user_id=eq.${userId}`,
        },
        () => {
          void load({ silent: true })
        },
      )
      .subscribe()
    return () => {
      cancelled = true
      void supabase!.removeChannel(channel)
    }
  }, [userId, showToast])

  async function openMessage(m: SystemMessage) {
    setOpen(m)
    if (m.read_at != null) return
    const readAt = new Date().toISOString()
    const { error } = await supabase!
      .from(SYSTEM_MESSAGES_TABLE)
      .update({ read_at: readAt })
      .eq('id', m.id)
      .eq('user_id', userId)
    if (error) {
      showToast(error.message, 'danger')
      return
    }
    setRows((prev) => prev.map((r) => (r.id === m.id ? { ...r, read_at: readAt } : r)))
    onUnreadMayHaveChanged?.()
  }

  async function removeMessage(m: SystemMessage) {
    const { error } = await supabase!
      .from(SYSTEM_MESSAGES_TABLE)
      .delete()
      .eq('id', m.id)
      .eq('user_id', userId)
    if (error) {
      showToast(error.message, 'danger')
      return
    }
    setPendingDeleteMessage(null)
    if (open?.id === m.id) setOpen(null)
    setRows((prev) => prev.filter((r) => r.id !== m.id))
    onUnreadMayHaveChanged?.()
    showToast('Message deleted', 'success')
  }

  return (
    <section className="panel">
      <h1>System Messages</h1>
      <p className="subtitle">Notifications from the system.</p>
      {loading ? (
        <p>Loading…</p>
      ) : rows.length === 0 ? (
        <p className="subtitle">No messages yet.</p>
      ) : (
        <div className="list">
          {rows.map((m) => (
            <div key={m.id} className="card upload-row system-message-row">
              <button type="button" className="system-message-open" onClick={() => void openMessage(m)}>
                <div className="row between" style={{ alignItems: 'flex-start', gap: 12 }}>
                  <strong
                    style={{
                      textAlign: 'left',
                      flex: 1,
                      minWidth: 0,
                      fontWeight: m.read_at == null ? 700 : 600,
                      wordBreak: 'break-word',
                      overflowWrap: 'anywhere',
                    }}
                  >
                    {m.title}
                  </strong>
                  <span className="message-time" style={{ flexShrink: 0 }}>
                    {new Date(m.created_at).toLocaleString()}
                  </span>
                </div>
                <p className="system-message-list-preview">{m.body}</p>
              </button>
              <button
                type="button"
                className="icon-danger"
                aria-label="Delete message"
                title="Delete message"
                onClick={() => setPendingDeleteMessage(m)}
              >
                🗑
              </button>
            </div>
          ))}
        </div>
      )}
      {open && (
        <div
          className="modal-backdrop"
          onClick={() => setOpen(null)}
          onKeyDown={(e) => e.key === 'Escape' && setOpen(null)}
          role="presentation"
        >
          <div
            className="modal modal-small"
            onClick={(e) => e.stopPropagation()}
            onKeyDown={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-labelledby="system-message-title"
          >
            <div className="row between" style={{ alignItems: 'flex-start', gap: 12 }}>
              <strong id="system-message-title" className="system-message-dialog-title">
                {open.title}
              </strong>
              <button type="button" className="secondary" onClick={() => setOpen(null)}>
                Close
              </button>
            </div>
            <p className="message-time">{new Date(open.created_at).toLocaleString()}</p>
            <p className="message-body">{open.body}</p>
          </div>
        </div>
      )}
      {pendingDeleteMessage && (
        <div className="modal-backdrop">
          <div className="modal modal-small">
            <strong>Delete message?</strong>
            <p>This will remove the message from your inbox.</p>
            <div className="row end">
              <button type="button" className="secondary" onClick={() => setPendingDeleteMessage(null)}>
                Cancel
              </button>
              <button type="button" className="danger" onClick={() => void removeMessage(pendingDeleteMessage)}>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

function ReviewUploadsTab() {
  const showToast = useToast()
  const [papers, setPapers] = useState<Paper[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedGroup, setSelectedGroup] = useState<Paper[] | null>(null)
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [pendingApprove, setPendingApprove] = useState<Paper[] | null>(null)
  const [pendingReject, setPendingReject] = useState<Paper[] | null>(null)
  const [busy, setBusy] = useState(false)

  async function load() {
    setLoading(true)
    const { data, error } = await supabase!
      .from(PAPERS_TABLE)
      .select('*')
      .eq('approval_status', 'pending')
      .order('created_at', { ascending: false })
    if (error) {
      showToast(error.message, 'danger')
      setPapers([])
    } else {
      setPapers((data as Paper[]) ?? [])
    }
    setLoading(false)
  }

  useEffect(() => {
    void load()
    const channel = supabase!
      .channel('papers_review_queue')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: PAPERS_TABLE },
        () => {
          void load()
        },
      )
      .subscribe()
    return () => {
      void supabase!.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- load uses stable showToast
  }, [])

  async function runReview(group: Paper[] | null, approve: boolean) {
    if (!group?.length) return
    setBusy(true)
    const ids = group.map((g) => g.id)
    const { error } = await supabase!.rpc('review_paper_upload', {
      p_paper_ids: ids,
      p_approve: approve,
    })
    setBusy(false)
    if (error) {
      showToast(error.message, 'danger')
      return
    }
    setPendingApprove(null)
    setPendingReject(null)
    if (selectedGroup?.some((s) => ids.includes(s.id))) {
      setSelectedGroup(null)
    }
    showToast(approve ? 'Upload approved' : 'Upload rejected', approve ? 'success' : 'default')
    await load()
  }

  const groups = useMemo(() => groupPapers(papers), [papers])

  return (
    <section className="panel">
      <h1>Review Uploads</h1>
      <p className="subtitle">Pending student uploads. Approve to publish to Papers, or reject to remove.</p>
      {loading ? (
        <p>Loading…</p>
      ) : groups.length === 0 ? (
        <p className="subtitle">No pending uploads.</p>
      ) : (
        <div className="list">
          {groups.map((group) => {
            const opener = group[0]
            const latest = group[group.length - 1]
            const listTitle =
              group.length > 1
                ? `${opener.title.replace(/\s\(\d+\)$/, '')} (${group.length} files)`
                : opener.title
            return (
              <div key={opener.id} className="card upload-row system-message-row">
                <button
                  type="button"
                  className="system-message-open"
                  onClick={() => {
                    setSelectedGroup(group)
                    setSelectedIndex(0)
                  }}
                >
                  <strong>{listTitle}</strong>
                  <span>{toMeta(opener)}</span>
                  <span className="message-time">{new Date(latest.created_at).toLocaleString()}</span>
                </button>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    className="secondary"
                    disabled={busy}
                    onClick={() => setPendingApprove(group)}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    className="danger"
                    disabled={busy}
                    onClick={() => setPendingReject(group)}
                  >
                    Reject
                  </button>
                </div>
              </div>
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
      {pendingApprove && (
        <div className="modal-backdrop">
          <div className="modal modal-small">
            <strong>Approve upload?</strong>
            <p>This will make the file(s) visible to everyone in Papers.</p>
            <div className="row end">
              <button type="button" className="secondary" disabled={busy} onClick={() => setPendingApprove(null)}>
                Cancel
              </button>
              <button type="button" disabled={busy} onClick={() => void runReview(pendingApprove, true)}>
                {busy ? 'Working…' : 'Approve'}
              </button>
            </div>
          </div>
        </div>
      )}
      {pendingReject && (
        <div className="modal-backdrop">
          <div className="modal modal-small">
            <strong>Reject upload?</strong>
            <p>The file(s) will be deleted from storage and cannot be recovered.</p>
            <div className="row end">
              <button type="button" className="secondary" disabled={busy} onClick={() => setPendingReject(null)}>
                Cancel
              </button>
              <button
                type="button"
                className="danger"
                disabled={busy}
                onClick={() => void runReview(pendingReject, false)}
              >
                {busy ? 'Working…' : 'Reject'}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

function UserTab({
  email,
  accountType,
  profileLoading,
  isAdmin,
  onGoToUploads,
}: {
  email: string
  accountType: string | null
  profileLoading: boolean
  isAdmin: boolean
  onGoToUploads: () => void
}) {
  const typeLine = profileLoading
    ? 'Account type: …'
    : `Account type: ${displayAccountTypeLabel(accountType)}`

  return (
    <section className="panel">
      <h1>User</h1>
      <p>{email || 'Not signed in'}</p>
      <p className="subtitle">{typeLine}</p>
      {isAdmin ? (
        <button type="button" className="secondary user-tab-row-btn" onClick={onGoToUploads}>
          My uploads
        </button>
      ) : null}
      <button type="button" onClick={() => supabase!.auth.signOut()}>
        Sign out
      </button>
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
  const showToast = useToast()
  const current = papers[index]
  const [url, setUrl] = useState('')
  const [previewFailed, setPreviewFailed] = useState(false)

  useEffect(() => {
    let mounted = true
    setPreviewFailed(false)
    setUrl('')
    supabase!.storage
      .from(BUCKET)
      .createSignedUrl(current.storage_path, 60 * 10)
      .then(({ data, error: err }) => {
        if (!mounted) return
        if (err) {
          showToast(err.message, 'danger')
          setPreviewFailed(true)
        } else setUrl(data.signedUrl)
      })
    return () => {
      mounted = false
    }
  }, [current.id, current.storage_path, showToast])

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
          {previewFailed ? (
            <p className="subtitle">Couldn&apos;t load preview.</p>
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
