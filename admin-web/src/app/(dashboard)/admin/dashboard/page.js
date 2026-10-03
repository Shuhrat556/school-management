'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  Activity,
  AlertCircle,
  ArrowRight,
  BookOpen,
  CheckCircle2,
  Clock3,
  GraduationCap,
  LayoutDashboard,
  RefreshCcw,
  School,
  ShieldCheck,
  TrendingUp,
  UserCheck,
  Users,
} from 'lucide-react';
import {
  adminGetUsers,
  getClassrooms,
  getGrades,
  getHealthDashboard,
  getStudents,
  getSubjects,
  getTeachers,
} from '@/lib/api';
import { getUser, useAuth } from '@/lib/auth';

const SOURCE_CONFIG = [
  { key: 'teachers', label: 'teacher records', load: () => getTeachers(1, 1000) },
  { key: 'students', label: 'student records', load: () => getStudents(1, 1000) },
  { key: 'classrooms', label: 'classroom records', load: () => getClassrooms(1, 1000) },
  { key: 'subjects', label: 'subject records', load: () => getSubjects() },
  { key: 'grades', label: 'grade records', load: () => getGrades() },
  { key: 'users', label: 'login accounts', load: () => adminGetUsers() },
  { key: 'health', label: 'service health', load: () => getHealthDashboard() },
];

const QUICK_ACTIONS = [
  {
    href: '/admin/students',
    label: 'Students',
    description: 'Manage enrollment and student records.',
    icon: GraduationCap,
    iconClassName: 'bg-amber-100 text-amber-700',
  },
  {
    href: '/admin/classrooms',
    label: 'Classrooms',
    description: 'Review sections, capacity, and staffing.',
    icon: School,
    iconClassName: 'bg-emerald-100 text-emerald-700',
  },
  {
    href: '/admin/users',
    label: 'Accounts',
    description: 'Handle roles, verification, and access.',
    icon: UserCheck,
    iconClassName: 'bg-rose-100 text-rose-700',
  },
  {
    href: '/admin/health',
    label: 'Platform Health',
    description: 'Monitor service availability in real time.',
    icon: Activity,
    iconClassName: 'bg-sky-100 text-sky-700',
  },
];

const ROLE_LABELS = {
  1: 'Teachers',
  2: 'Students',
  3: 'Parents',
  4: 'Admins',
};

const ROLE_STYLES = {
  Teachers: 'bg-sky-100 text-sky-700',
  Students: 'bg-amber-100 text-amber-700',
  Parents: 'bg-emerald-100 text-emerald-700',
  Admins: 'bg-rose-100 text-rose-700',
  Other: 'bg-slate-100 text-slate-700',
};

const ENTITY_META = {
  student: {
    label: 'Student',
    href: (item) => `/admin/students/${item.id}`,
    icon: GraduationCap,
    iconClassName: 'bg-amber-100 text-amber-700',
  },
  teacher: {
    label: 'Teacher',
    href: (item) => `/admin/teachers/${item.id}`,
    icon: Users,
    iconClassName: 'bg-sky-100 text-sky-700',
  },
  classroom: {
    label: 'Classroom',
    href: (item) => `/admin/classrooms/${item.id}`,
    icon: School,
    iconClassName: 'bg-emerald-100 text-emerald-700',
  },
  subject: {
    label: 'Subject',
    href: (item) => `/admin/subjects/${item.id}`,
    icon: BookOpen,
    iconClassName: 'bg-violet-100 text-violet-700',
  },
};

function toItems(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.items)) return data.items;
  return [];
}

function getTotalCount(data) {
  if (typeof data?.totalCount === 'number') return data.totalCount;
  return toItems(data).length;
}

function formatNumber(value) {
  return new Intl.NumberFormat().format(value ?? 0);
}

function getSubjectYearLevel(subject) {
  if (subject?.yearLevel) return subject.yearLevel;
  const match = String(subject?.code ?? subject?.subjectName ?? '').match(/Y(\d+)\b/i);
  return match ? Number(match[1]) : null;
}

function formatPercent(value, digits = 0) {
  if (!Number.isFinite(value)) return '--';
  return `${value.toFixed(digits)}%`;
}

function formatRatio(left, right) {
  if (!right) return '--';
  return `${(left / right).toFixed(1)} : 1`;
}

function formatDateTime(value) {
  if (!value) return 'No timestamp';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'No timestamp';
  return date.toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

function roleLabelFor(user) {
  const value = Number(user?.role ?? user?.userRole ?? 0);
  return ROLE_LABELS[value] ?? String(user?.userRole ?? 'Other');
}

function getRoleChipClass(label) {
  return ROLE_STYLES[label] ?? ROLE_STYLES.Other;
}

function buildRecentItems(items, type, makeTitle, makeDescription) {
  return items
    .filter((item) => item?.createdAt)
    .map((item) => ({
      id: `${type}-${item.id}`,
      type,
      title: makeTitle(item),
      description: makeDescription(item),
      createdAt: item.createdAt,
      item,
    }));
}

function buildDashboardModel(rawData = {}) {
  const teachers = toItems(rawData.teachers);
  const students = toItems(rawData.students);
  const classrooms = toItems(rawData.classrooms);
  const subjects = toItems(rawData.subjects);
  const grades = toItems(rawData.grades);
  const users = toItems(rawData.users);
  const health = rawData.health ?? null;

  const teacherTotal = getTotalCount(rawData.teachers);
  const studentTotal = getTotalCount(rawData.students);
  const classroomTotal = getTotalCount(rawData.classrooms);
  const subjectTotal = getTotalCount(rawData.subjects);
  const userTotal = getTotalCount(rawData.users);

  const verifiedAccounts = users.filter((user) => user?.isEmailVerified).length;
  const pendingAccounts = Math.max(userTotal - verifiedAccounts, 0);
  const unassignedClassrooms = classrooms.filter((classroom) => !(classroom?.teacherName || classroom?.teacherId));
  const assignedSubjects = subjects.filter((subject) => Array.isArray(subject?.teacherNames) && subject.teacherNames.length > 0).length;
  const unassignedSubjects = Math.max(subjectTotal - assignedSubjects, 0);
  const totalStudentsAssigned = classrooms.reduce(
    (sum, classroom) => sum + Number(classroom?.studentCount ?? classroom?.students?.length ?? 0),
    0,
  );
  const averageClassSize = classroomTotal ? totalStudentsAssigned / classroomTotal : 0;
  const averageGrade =
    grades.length > 0
      ? grades.reduce((sum, grade) => sum + Number(grade?.score ?? 0), 0) / grades.length
      : null;
  const lowGrades = grades.filter((grade) => Number(grade?.score ?? 0) < 60).length;

  const services = Array.isArray(health?.services) ? health.services : [];
  const totalServices = Number(health?.totalServices ?? services.length ?? 0);
  const healthyServices = Number(
    health?.summary?.healthyServices ??
      services.filter((service) => String(service?.status).toLowerCase() === 'healthy').length,
  );
  const unhealthyServices = Number(
    health?.summary?.unhealthyServices ?? Math.max(totalServices - healthyServices, 0),
  );
  const healthyServiceRate = totalServices ? (healthyServices / totalServices) * 100 : 0;

  const departmentMap = subjects.reduce((accumulator, subject) => {
    const key = subject?.department || subject?.category || 'General Studies';
    accumulator.set(key, (accumulator.get(key) ?? 0) + 1);
    return accumulator;
  }, new Map());

  const programDistribution = [...departmentMap.entries()]
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .slice(0, 5)
    .map(([label, count]) => ({
      label,
      count,
      percent: subjectTotal ? (count / subjectTotal) * 100 : 0,
    }));

  const yearMap = subjects.reduce((accumulator, subject) => {
    const yearLevel = getSubjectYearLevel(subject);
    const key = yearLevel ? `Year ${yearLevel}` : 'Unassigned';
    accumulator.set(key, (accumulator.get(key) ?? 0) + 1);
    return accumulator;
  }, new Map());

  const yearBreakdown = [...yearMap.entries()]
    .sort((left, right) => left[0].localeCompare(right[0], undefined, { numeric: true }))
    .map(([label, count]) => ({ label, count }));

  const roleCounts = users.reduce((accumulator, user) => {
    const label = roleLabelFor(user);
    accumulator.set(label, (accumulator.get(label) ?? 0) + 1);
    return accumulator;
  }, new Map());

  const roles = [...roleCounts.entries()]
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .map(([label, count]) => ({
      label,
      count,
      percent: userTotal ? (count / userTotal) * 100 : 0,
    }));

  const recentActivity = [
    ...buildRecentItems(
      students,
      'student',
      (student) => `${student.firstName ?? ''} ${student.lastName ?? ''}`.trim() || 'New student',
      (student) => student.email || student.phone || student.address || 'Student profile created',
    ),
    ...buildRecentItems(
      teachers,
      'teacher',
      (teacher) => `${teacher.firstName ?? ''} ${teacher.lastName ?? ''}`.trim() || 'New teacher',
      (teacher) => teacher.department || teacher.specialization || teacher.email || 'Teacher profile created',
    ),
    ...buildRecentItems(
      classrooms,
      'classroom',
      (classroom) => classroom.className || classroom.name || 'New classroom',
      (classroom) => classroom.grade || classroom.academicYear || 'Classroom created',
    ),
    ...buildRecentItems(
      subjects,
      'subject',
      (subject) => subject.subjectName || 'New subject',
      (subject) => subject.department || subject.category || subject.code || 'Subject created',
    ),
  ]
    .sort((left, right) => new Date(right.createdAt) - new Date(left.createdAt))
    .slice(0, 6);

  const crowdedClassrooms = [...classrooms]
    .sort(
      (left, right) =>
        Number(right?.studentCount ?? right?.students?.length ?? 0) -
        Number(left?.studentCount ?? left?.students?.length ?? 0),
    )
    .slice(0, 5)
    .map((classroom) => ({
      id: classroom.id,
      name: classroom.className || classroom.name || 'Unnamed classroom',
      grade: classroom.grade || classroom.academicYear || 'No grade set',
      students: Number(classroom?.studentCount ?? classroom?.students?.length ?? 0),
      teacherName: classroom.teacherName || 'Teacher not assigned',
    }));

  const watchlist = [
    {
      label: 'Accounts pending email verification',
      count: pendingAccounts,
      href: '/admin/users',
      tone: pendingAccounts > 0 ? 'amber' : 'green',
      note: pendingAccounts > 0 ? 'Follow up to reduce login friction.' : 'All visible accounts are verified.',
    },
    {
      label: 'Classrooms missing a teacher',
      count: unassignedClassrooms.length,
      href: '/admin/classrooms',
      tone: unassignedClassrooms.length > 0 ? 'amber' : 'green',
      note: unassignedClassrooms.length > 0 ? 'Assign homeroom ownership where needed.' : 'Every classroom has a teacher.',
    },
    {
      label: 'Subjects without assigned teachers',
      count: unassignedSubjects,
      href: '/admin/subjects',
      tone: unassignedSubjects > 0 ? 'amber' : 'green',
      note: unassignedSubjects > 0 ? 'Coverage gaps may block schedules.' : 'Subject coverage is complete.',
    },
    {
      label: 'Recorded grades below 60',
      count: lowGrades,
      href: '/admin/grades',
      tone: lowGrades > 0 ? 'rose' : 'green',
      note: lowGrades > 0 ? 'Review intervention or support plans.' : 'No failing grades in the current grade data.',
    },
    {
      label: 'Unhealthy platform services',
      count: unhealthyServices,
      href: '/admin/health',
      tone: unhealthyServices > 0 ? 'rose' : 'green',
      note: unhealthyServices > 0 ? 'Investigate service availability.' : 'All reported services are healthy.',
    },
  ];

  return {
    counts: {
      teachers: teacherTotal,
      students: studentTotal,
      classrooms: classroomTotal,
      subjects: subjectTotal,
      users: userTotal,
      verifiedAccounts,
      healthyServices,
      totalServices,
    },
    metrics: {
      studentTeacherRatio: formatRatio(studentTotal, teacherTotal),
      averageClassSize,
      assignedSubjects,
      subjectCoverageRate: subjectTotal ? (assignedSubjects / subjectTotal) * 100 : 0,
      averageGrade,
      lowGrades,
      healthyServiceRate,
    },
    roles,
    yearBreakdown,
    programDistribution,
    recentActivity,
    crowdedClassrooms,
    watchlist,
    services: services.slice(0, 6),
  };
}

function StatCard({ label, value, helper, href, icon: Icon, iconClassName, loading }) {
  const content = (
    <div className="group h-full rounded-[1.6rem] border border-slate-200/70 bg-white/88 p-5 shadow-[0_18px_40px_-34px_rgba(15,23,42,0.5)] transition duration-200 hover:-translate-y-0.5 hover:border-slate-300 hover:shadow-[0_22px_48px_-34px_rgba(15,23,42,0.55)]">
      <div className="flex items-start justify-between gap-4">
        <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${iconClassName}`}>
          <Icon className="h-5 w-5" />
        </div>
        <ArrowRight className="h-4 w-4 text-slate-300 transition group-hover:text-slate-500" />
      </div>
      <p className="mt-6 text-sm font-medium text-slate-500">{label}</p>
      <p className="mt-2 text-3xl font-semibold tracking-tight text-slate-950">
        {loading ? <span className="animate-pulse text-slate-300">--</span> : value}
      </p>
      <p className="mt-2 text-sm text-slate-500">{helper}</p>
    </div>
  );

  if (!href) return <div>{content}</div>;
  return <Link href={href}>{content}</Link>;
}

function toneClasses(tone) {
  if (tone === 'rose') return 'bg-rose-100 text-rose-700';
  if (tone === 'amber') return 'bg-amber-100 text-amber-700';
  return 'bg-emerald-100 text-emerald-700';
}

export default function AdminDashboardPage() {
  useAuth([4]);

  const [user, setUser] = useState(null);
  const [dashboard, setDashboard] = useState(() => buildDashboardModel());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [warnings, setWarnings] = useState([]);
  const [lastUpdated, setLastUpdated] = useState(null);

  async function loadDashboard() {
    setLoading(true);
    setError('');

    const results = await Promise.allSettled(SOURCE_CONFIG.map((source) => source.load()));
    const nextData = {};
    const nextWarnings = [];

    results.forEach((result, index) => {
      const source = SOURCE_CONFIG[index];
      if (result.status === 'fulfilled' && result.value !== null) {
        nextData[source.key] = result.value;
      } else {
        nextData[source.key] = null;
        nextWarnings.push(source.label);
      }
    });

    setDashboard(buildDashboardModel(nextData));
    setWarnings(nextWarnings);
    setLastUpdated(nextWarnings.length === SOURCE_CONFIG.length ? null : new Date().toISOString());

    if (nextWarnings.length === SOURCE_CONFIG.length) {
      setError('The dashboard could not load any of the configured endpoints. Check the API gateway and authentication state.');
    }

    setLoading(false);
  }

  useEffect(() => {
    setUser(getUser());
    loadDashboard();
  }, []);

  const todayLabel = new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });
  const greetingName = user?.firstName || user?.email?.split('@')[0] || 'Admin';
  const availableSources = SOURCE_CONFIG.length - warnings.length;

  const statCards = [
    {
      label: 'Student Records',
      value: formatNumber(dashboard.counts.students),
      helper: `${formatNumber(Math.round(dashboard.metrics.averageClassSize || 0))} avg per classroom`,
      href: '/admin/students',
      icon: GraduationCap,
      iconClassName: 'bg-amber-100 text-amber-700',
    },
    {
      label: 'Teacher Records',
      value: formatNumber(dashboard.counts.teachers),
      helper: `${dashboard.metrics.studentTeacherRatio} student-teacher ratio`,
      href: '/admin/teachers',
      icon: Users,
      iconClassName: 'bg-sky-100 text-sky-700',
    },
    {
      label: 'Classrooms',
      value: formatNumber(dashboard.counts.classrooms),
      helper: `${formatNumber(dashboard.crowdedClassrooms[0]?.students ?? 0)} highest visible enrollment`,
      href: '/admin/classrooms',
      icon: School,
      iconClassName: 'bg-emerald-100 text-emerald-700',
    },
    {
      label: 'Subjects',
      value: formatNumber(dashboard.counts.subjects),
      helper: `${formatPercent(dashboard.metrics.subjectCoverageRate)} currently staffed`,
      href: '/admin/subjects',
      icon: BookOpen,
      iconClassName: 'bg-violet-100 text-violet-700',
    },
    {
      label: 'Verified Accounts',
      value: `${formatNumber(dashboard.counts.verifiedAccounts)} / ${formatNumber(dashboard.counts.users)}`,
      helper: dashboard.counts.users
        ? `${formatPercent((dashboard.counts.verifiedAccounts / dashboard.counts.users) * 100)} verification rate`
        : 'No account data yet',
      href: '/admin/users',
      icon: UserCheck,
      iconClassName: 'bg-rose-100 text-rose-700',
    },
    {
      label: 'Healthy Services',
      value: `${formatNumber(dashboard.counts.healthyServices)} / ${formatNumber(dashboard.counts.totalServices)}`,
      helper: dashboard.counts.totalServices
        ? `${formatPercent(dashboard.metrics.healthyServiceRate)} uptime coverage`
        : 'Health endpoint unavailable',
      href: '/admin/health',
      icon: Activity,
      iconClassName: 'bg-slate-200 text-slate-700',
    },
  ];

  return (
    <div className="space-y-8">
      <section className="relative overflow-hidden rounded-[2rem] border border-slate-200/70 bg-[linear-gradient(135deg,#f7fafb_0%,#eef3f6_52%,#e2ebf0_100%)] p-6 shadow-[0_24px_80px_-48px_rgba(15,23,42,0.45)] sm:p-8">
        <div className="absolute right-[-10%] top-[-12%] h-64 w-64 rounded-full bg-white/40 blur-3xl" />
        <div className="absolute bottom-[-24%] left-[-6%] h-56 w-56 rounded-full bg-slate-200/70 blur-3xl" />

        <div className="relative flex flex-col gap-8 xl:flex-row xl:items-end xl:justify-between">
          <div className="max-w-3xl">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/80 bg-white/70 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">
              <LayoutDashboard className="h-3.5 w-3.5 text-slate-700" />
              Admin Command Center
            </div>

            <h1 className="mt-5 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
              School administration dashboard
            </h1>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-600 sm:text-base">
              Welcome back, {greetingName}. This overview is built from the current school, auth, and service-health
              endpoints so you can review enrollment, staffing, platform status, and academic coverage in one place.
            </p>

            <div className="mt-6 flex flex-wrap gap-3 text-sm text-slate-600">
              <span className="inline-flex items-center gap-2 rounded-full border border-white/80 bg-white/80 px-3 py-2">
                <Clock3 className="h-4 w-4 text-slate-500" />
                {todayLabel}
              </span>
              <span className="inline-flex items-center gap-2 rounded-full border border-white/80 bg-white/80 px-3 py-2">
                <ShieldCheck className="h-4 w-4 text-emerald-600" />
                {availableSources}/{SOURCE_CONFIG.length} data sources connected
              </span>
            </div>

            <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {QUICK_ACTIONS.map(({ href, label, description, icon: Icon, iconClassName }) => (
                <Link
                  key={href}
                  href={href}
                  className="group rounded-[1.4rem] border border-white/75 bg-white/80 p-4 shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-slate-300 hover:bg-white"
                >
                  <div className={`flex h-11 w-11 items-center justify-center rounded-2xl ${iconClassName}`}>
                    <Icon className="h-5 w-5" />
                  </div>
                  <h2 className="mt-4 text-sm font-semibold text-slate-900">{label}</h2>
                  <p className="mt-1 text-xs leading-5 text-slate-500">{description}</p>
                </Link>
              ))}
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 xl:w-[25rem]">
            <div className="rounded-[1.5rem] border border-white/80 bg-white/82 p-5 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Last Sync</p>
              <p className="mt-3 text-lg font-semibold text-slate-950">
                {loading ? 'Refreshing...' : lastUpdated ? formatDateTime(lastUpdated) : 'No successful sync yet'}
              </p>
              <p className="mt-2 text-sm text-slate-500">
                Refresh pulls the latest values from the existing backend endpoints.
              </p>
            </div>

            <div className="rounded-[1.5rem] border border-white/80 bg-white/82 p-5 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Coverage</p>
              <p className="mt-3 text-lg font-semibold text-slate-950">
                {availableSources === SOURCE_CONFIG.length ? 'Complete data' : `${warnings.length} source${warnings.length === 1 ? '' : 's'} degraded`}
              </p>
              <p className="mt-2 text-sm text-slate-500">
                {warnings.length === 0
                  ? 'Every dashboard widget is backed by a live response right now.'
                  : 'Some cards may show partial information until the affected endpoints recover.'}
              </p>
            </div>

            <button
              type="button"
              onClick={loadDashboard}
              disabled={loading}
              className="inline-flex items-center justify-center gap-3 rounded-[1.5rem] border border-slate-300 bg-slate-900 px-5 py-4 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-wait disabled:opacity-75 sm:col-span-2"
            >
              <RefreshCcw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              {loading ? 'Refreshing dashboard' : 'Refresh data'}
            </button>
          </div>
        </div>
      </section>

      {error && (
        <div className="flex items-start gap-3 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 text-sm text-rose-700">
          <AlertCircle className="mt-0.5 h-5 w-5 shrink-0" />
          <div>
            <p className="font-semibold">Dashboard data is unavailable</p>
            <p className="mt-1">{error}</p>
          </div>
        </div>
      )}

      {!error && warnings.length > 0 && (
        <div className="flex items-start gap-3 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-4 text-sm text-amber-800">
          <AlertCircle className="mt-0.5 h-5 w-5 shrink-0" />
          <div>
            <p className="font-semibold">Partial data loaded</p>
            <p className="mt-1">
              Some endpoints did not respond: {warnings.join(', ')}. The rest of the dashboard is still using the live
              responses that were available.
            </p>
          </div>
        </div>
      )}

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {statCards.map((card) => (
          <StatCard key={card.label} {...card} loading={loading} />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.15fr_0.95fr_0.9fr]">
        <div className="admin-card rounded-[1.8rem] p-6">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-slate-100 text-slate-700">
              <TrendingUp className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Operations Pulse</p>
              <h2 className="mt-1 text-xl font-semibold text-slate-950">Enrollment, staffing, and academics</h2>
            </div>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            {[
              {
                label: 'Student-teacher ratio',
                value: dashboard.metrics.studentTeacherRatio,
                note: 'Visible roster balance across current records',
              },
              {
                label: 'Average class size',
                value: `${Math.round(dashboard.metrics.averageClassSize || 0)} students`,
                note: 'Based on current classroom enrollment totals',
              },
              {
                label: 'Subject coverage',
                value: `${dashboard.metrics.assignedSubjects} / ${dashboard.counts.subjects}`,
                note: `${formatPercent(dashboard.metrics.subjectCoverageRate)} of subjects have teacher assignments`,
              },
              {
                label: 'Average grade',
                value: dashboard.metrics.averageGrade !== null ? `${dashboard.metrics.averageGrade.toFixed(1)}%` : 'No grades yet',
                note:
                  dashboard.metrics.averageGrade !== null
                    ? `${formatNumber(dashboard.metrics.lowGrades)} grades below 60 need attention`
                    : 'Grade endpoint has not returned assessment data yet',
              },
            ].map((item) => (
              <div key={item.label} className="rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">{item.label}</p>
                <p className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
                  {loading ? <span className="animate-pulse text-slate-300">--</span> : item.value}
                </p>
                <p className="mt-2 text-sm leading-6 text-slate-500">{item.note}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-card rounded-[1.8rem] p-6">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-violet-100 text-violet-700">
              <BookOpen className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Program Mix</p>
              <h2 className="mt-1 text-xl font-semibold text-slate-950">Subjects by department or track</h2>
            </div>
          </div>

          {dashboard.programDistribution.length === 0 ? (
            <div className="mt-6 rounded-[1.4rem] border border-dashed border-slate-200 bg-slate-50/80 p-6 text-sm text-slate-500">
              Subject metadata has not loaded yet, so the program mix is waiting for backend data.
            </div>
          ) : (
            <div className="mt-6 space-y-4">
              {dashboard.programDistribution.map((group) => (
                <div key={group.label}>
                  <div className="flex items-center justify-between gap-3 text-sm">
                    <p className="font-medium text-slate-700">{group.label}</p>
                    <p className="text-slate-500">
                      {formatNumber(group.count)} subject{group.count === 1 ? '' : 's'}
                    </p>
                  </div>
                  <div className="mt-2 h-2.5 overflow-hidden rounded-full bg-slate-100">
                    <div
                      className="h-full rounded-full bg-slate-700"
                      style={{ width: `${Math.max(group.percent, 6)}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="mt-6 border-t border-slate-100 pt-5">
            <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Year Levels</p>
            <div className="mt-3 flex flex-wrap gap-2">
              {dashboard.yearBreakdown.length === 0 ? (
                <span className="rounded-full bg-slate-100 px-3 py-1.5 text-xs text-slate-500">No year data</span>
              ) : (
                dashboard.yearBreakdown.map((item) => (
                  <span
                    key={item.label}
                    className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-medium text-slate-600"
                  >
                    {item.label}: {formatNumber(item.count)}
                  </span>
                ))
              )}
            </div>
          </div>
        </div>

        <div className="admin-card rounded-[1.8rem] p-6">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-emerald-100 text-emerald-700">
              <ShieldCheck className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Platform Status</p>
              <h2 className="mt-1 text-xl font-semibold text-slate-950">Services and account access</h2>
            </div>
          </div>

          <div className="mt-6 rounded-[1.4rem] border border-slate-200/70 bg-slate-50/80 p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-slate-700">Service health coverage</p>
                <p className="mt-1 text-xs text-slate-500">
                  {dashboard.counts.totalServices
                    ? `${formatNumber(dashboard.counts.healthyServices)} of ${formatNumber(dashboard.counts.totalServices)} services are healthy`
                    : 'No service-health payload available'}
                </p>
              </div>
              <div className="rounded-full bg-white px-3 py-1 text-sm font-semibold text-slate-700 shadow-sm">
                {formatPercent(dashboard.metrics.healthyServiceRate)}
              </div>
            </div>

            <div className="mt-4 h-2.5 overflow-hidden rounded-full bg-white">
              <div
                className="h-full rounded-full bg-emerald-500"
                style={{ width: `${Math.max(dashboard.metrics.healthyServiceRate, dashboard.counts.totalServices ? 6 : 0)}%` }}
              />
            </div>
          </div>

          <div className="mt-5 rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-slate-700">Account verification</p>
                <p className="mt-1 text-xs text-slate-500">
                  {dashboard.counts.users
                    ? `${formatNumber(dashboard.counts.verifiedAccounts)} of ${formatNumber(dashboard.counts.users)} accounts are verified`
                    : 'No account payload available'}
                </p>
              </div>
              <div className="rounded-full bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-700">
                {dashboard.counts.users
                  ? formatPercent((dashboard.counts.verifiedAccounts / dashboard.counts.users) * 100)
                  : '--'}
              </div>
            </div>

            <div className="mt-4 h-2.5 overflow-hidden rounded-full bg-slate-100">
              <div
                className="h-full rounded-full bg-slate-700"
                style={{
                  width: `${Math.max(
                    dashboard.counts.users
                      ? (dashboard.counts.verifiedAccounts / dashboard.counts.users) * 100
                      : 0,
                    dashboard.counts.users ? 6 : 0,
                  )}%`,
                }}
              />
            </div>
          </div>

          <div className="mt-5 border-t border-slate-100 pt-5">
            <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Login Accounts by Role</p>
            <div className="mt-3 flex flex-wrap gap-2">
              {dashboard.roles.length === 0 ? (
                <span className="rounded-full bg-slate-100 px-3 py-1.5 text-xs text-slate-500">No user role data</span>
              ) : (
                dashboard.roles.map((role) => (
                  <span
                    key={role.label}
                    className={`rounded-full px-3 py-1.5 text-xs font-semibold ${getRoleChipClass(role.label)}`}
                  >
                    {role.label}: {formatNumber(role.count)}
                  </span>
                ))
              )}
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="admin-card rounded-[1.8rem] p-6">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Recent Records</p>
              <h2 className="mt-1 text-xl font-semibold text-slate-950">Latest additions across the system</h2>
            </div>
            <Link
              href="/admin/students"
              className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              View modules
              <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </div>

          {dashboard.recentActivity.length === 0 ? (
            <div className="mt-6 rounded-[1.4rem] border border-dashed border-slate-200 bg-slate-50/80 p-6 text-sm text-slate-500">
              No recent created records are visible yet. Once the backend returns timestamps, new additions will appear
              here automatically.
            </div>
          ) : (
            <div className="mt-6 space-y-3">
              {dashboard.recentActivity.map((entry) => {
                const meta = ENTITY_META[entry.type];
                const Icon = meta.icon;

                return (
                  <Link
                    key={entry.id}
                    href={meta.href(entry.item)}
                    className="flex items-start gap-4 rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4 transition hover:-translate-y-0.5 hover:border-slate-300 hover:bg-white"
                  >
                    <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ${meta.iconClassName}`}>
                      <Icon className="h-5 w-5" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="text-sm font-semibold text-slate-900">{entry.title}</p>
                        <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
                          {meta.label}
                        </span>
                      </div>
                      <p className="mt-1 truncate text-sm text-slate-500">{entry.description}</p>
                      <p className="mt-2 text-xs text-slate-400">{formatDateTime(entry.createdAt)}</p>
                    </div>
                    <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-slate-300" />
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        <div className="space-y-6">
          <div className="admin-card rounded-[1.8rem] p-6">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-amber-100 text-amber-700">
                <AlertCircle className="h-5 w-5" />
              </div>
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Watchlist</p>
                <h2 className="mt-1 text-xl font-semibold text-slate-950">Items that need administrator attention</h2>
              </div>
            </div>

            <div className="mt-6 space-y-3">
              {dashboard.watchlist.map((item) => (
                <Link
                  key={item.label}
                  href={item.href}
                  className="flex items-start justify-between gap-4 rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4 transition hover:border-slate-300 hover:bg-white"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-slate-900">{item.label}</p>
                    <p className="mt-1 text-sm text-slate-500">{item.note}</p>
                  </div>
                  <div className={`rounded-full px-3 py-1 text-sm font-semibold ${toneClasses(item.tone)}`}>
                    {formatNumber(item.count)}
                  </div>
                </Link>
              ))}
            </div>
          </div>

          <div className="admin-card rounded-[1.8rem] p-6">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-slate-100 text-slate-700">
                <School className="h-5 w-5" />
              </div>
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Class Capacity</p>
                <h2 className="mt-1 text-xl font-semibold text-slate-950">Most populated classrooms</h2>
              </div>
            </div>

            {dashboard.crowdedClassrooms.length === 0 ? (
              <div className="mt-6 rounded-[1.4rem] border border-dashed border-slate-200 bg-slate-50/80 p-6 text-sm text-slate-500">
                Classroom enrollment data has not loaded yet.
              </div>
            ) : (
              <div className="mt-6 space-y-3">
                {dashboard.crowdedClassrooms.map((classroom) => (
                  <Link
                    key={classroom.id}
                    href={`/admin/classrooms/${classroom.id}`}
                    className="block rounded-[1.4rem] border border-slate-200/70 bg-white/80 p-4 transition hover:border-slate-300 hover:bg-white"
                  >
                    <div className="flex w-full items-start justify-between gap-4">
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-slate-900">{classroom.name}</p>
                        <p className="mt-1 text-sm text-slate-600">
                          {classroom.grade} | {classroom.teacherName}
                        </p>
                      </div>
                      <div className="flex-shrink-0 rounded-full bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-700">
                        {formatNumber(classroom.students)}
                      </div>
                    </div>
                  </Link>
                ))}
              </div>
            )}

            {dashboard.services.length > 0 && (
              <div className="mt-6 border-t border-slate-100 pt-5">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Service Detail</p>
                <div className="mt-3 space-y-2">
                  {dashboard.services.map((service) => {
                    const healthy = String(service?.status).toLowerCase() === 'healthy';
                    return (
                      <div
                        key={service.serviceName}
                        className="flex items-center justify-between gap-4 rounded-2xl border border-slate-200/70 bg-slate-50/80 px-4 py-3"
                      >
                        <div>
                          <p className="text-sm font-medium text-slate-800">{service.serviceName}</p>
                          <p className="mt-1 text-xs text-slate-500">
                            {formatNumber(service.healthyInstances ?? 0)} healthy / {formatNumber(service.totalInstances ?? 0)} instances
                          </p>
                        </div>
                        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${healthy ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                          {service.status}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      </section>

      {!loading && !error && availableSources === SOURCE_CONFIG.length && (
        <div className="flex items-start gap-3 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-800">
          <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0" />
          <div>
            <p className="font-semibold">Dashboard synced successfully</p>
            <p className="mt-1">All configured endpoints responded, and the admin overview is showing live data end to end.</p>
          </div>
        </div>
      )}
    </div>
  );
}

