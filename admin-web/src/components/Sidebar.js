'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { logout, getUser } from '@/lib/auth';
import { getUnreadNotificationCount } from '@/lib/api';
import {
  Activity,
  BarChart3,
  Bell,
  BookOpen,
  Building2,
  CalendarDays,
  ChevronRight,
  ClipboardCheck,
  FileText,
  CalendarClock,
  GraduationCap,
  History,
  LayoutDashboard,
  LogOut,
  Menu,
  School,
  UserCog,
  Users,
  X,
  Home,
} from 'lucide-react';

const adminSections = [
  {
    title: 'Overview',
    items: [
      { href: '/admin/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/admin/curriculum', label: 'Curriculum', icon: BookOpen },
    ],
  },
  {
    title: 'People',
    items: [
      { href: '/admin/teachers', label: 'Teachers', icon: Users },
      { href: '/admin/students', label: 'Students', icon: GraduationCap },
      { href: '/admin/users', label: 'Users', icon: UserCog },
    ],
  },
  {
    title: 'Academics',
    items: [
      { href: '/admin/departments', label: 'Departments', icon: Building2 },
      { href: '/admin/classrooms', label: 'Classrooms', icon: School },
      { href: '/admin/rooms', label: 'Rooms', icon: Home },
      { href: '/admin/subjects', label: 'Subjects', icon: BookOpen },
      { href: '/admin/grades', label: 'Grades', icon: BarChart3 },
      { href: '/admin/grade-changes', label: 'Grade history', icon: History },
      { href: '/leave-requests', label: 'Leave requests', icon: CalendarClock },
      { href: '/admin/attendance', label: 'Attendance', icon: ClipboardCheck },
      { href: '/admin/schedules', label: 'Schedules', icon: CalendarDays },
    ],
  },
  {
    title: 'System',
    items: [
      { href: '/admin/health', label: 'Health', icon: Activity },
    ],
  },
];

const teacherSections = [
  {
    title: 'Teaching',
    items: [
      { href: '/teacher/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/teacher/classrooms', label: 'Classrooms', icon: School },
      { href: '/teacher/attendance', label: 'Attendance', icon: ClipboardCheck },
      { href: '/teacher/grades', label: 'Grades', icon: BarChart3 },
      { href: '/leave-requests', label: 'Leave requests', icon: CalendarClock },
    ],
  },
];

const studentSections = [
  {
    title: 'Overview',
    items: [
      { href: '/student/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/notifications', label: 'Notifications', icon: Bell, showUnread: true },
    ],
  },
  {
    title: 'Academics',
    items: [
      { href: '/student/academics', label: 'Academics', icon: BookOpen },
      { href: '/student/grades', label: 'Grades', icon: BarChart3 },
      { href: '/report-card/me', label: 'Report card', icon: FileText },
      { href: '/student/attendance', label: 'Attendance', icon: ClipboardCheck },
      { href: '/student/schedules', label: 'Schedules', icon: CalendarDays },
    ],
  },
  {
    title: 'Resources',
    items: [
      { href: '/student/assignments', label: 'Assignments', icon: ClipboardCheck },
      { href: '/student/materials', label: 'Materials', icon: BookOpen },
      { href: '/student/announcements', label: 'Announcements', icon: Activity },
      { href: '/student/profile', label: 'Profile', icon: GraduationCap },
    ],
  },
];

const parentSections = [
  {
    title: 'Family',
    items: [
      { href: '/parent/dashboard', label: 'My children', icon: Users },
      { href: '/parent/leave-requests', label: 'Leave requests', icon: CalendarClock },
      { href: '/notifications', label: 'Notifications', icon: Bell, showUnread: true },
    ],
  },
];

function getRoleMeta(role) {
  if (role === 4) return { label: 'Administrator', sections: adminSections };
  if (role === 1) return { label: 'Teacher', sections: teacherSections };
  if (role === 2) return { label: 'Student', sections: studentSections };
  if (role === 3) return { label: 'Parent', sections: parentSections };
  return { label: 'Workspace', sections: [] };
}

export default function Sidebar() {
  const pathname = usePathname();
  const [user, setUser] = useState(null);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    setUser(getUser());
  }, []);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  // Students and parents see how many notifications they haven't read yet
  const [unread, setUnread] = useState(0);
  const role = user?.role;
  useEffect(() => {
    if (role !== 2 && role !== 3) return;
    let active = true;
    getUnreadNotificationCount().then((count) => {
      if (active) setUnread(count);
    });
    return () => {
      active = false;
    };
  }, [role, pathname]);

  const roleMeta = getRoleMeta(user?.role);

  return (
    <>
      <div className="sticky top-0 z-30 flex items-center justify-between border-b border-[var(--app-border)] bg-[rgba(248,249,250,0.92)] px-4 py-3 backdrop-blur lg:hidden print:hidden">
        <Link href={roleMeta.sections[0]?.items[0]?.href ?? '/'} className="flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[#526d82] text-white shadow-lg shadow-slate-900/15">
            <School className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-semibold text-[var(--app-text-strong)]">School Operations</p>
            <p className="text-xs text-[var(--app-text-muted)]">{roleMeta.label}</p>
          </div>
        </Link>

        <button
          type="button"
          onClick={() => setMobileOpen((prev) => !prev)}
          className="rounded-2xl border border-[var(--app-border)] bg-white p-2.5 text-[var(--app-text)] shadow-sm transition hover:border-[var(--app-border-strong)] hover:text-[var(--app-text-strong)]"
          aria-label={mobileOpen ? 'Close navigation' : 'Open navigation'}
        >
          {mobileOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {mobileOpen && (
        <button
          type="button"
          onClick={() => setMobileOpen(false)}
          className="fixed inset-0 z-30 bg-slate-950/20 backdrop-blur-sm lg:hidden"
          aria-label="Close navigation overlay"
        />
      )}

      <aside
        className={[
          'fixed inset-y-0 left-0 z-40 flex w-[19rem] max-w-[86vw] flex-col border-r border-[var(--app-border)] bg-[#edf1f4] text-[var(--app-text)] shadow-2xl shadow-slate-900/8 transition-transform duration-300 lg:static lg:z-auto lg:w-72 lg:max-w-none lg:translate-x-0 print:hidden',
          mobileOpen ? 'translate-x-0' : '-translate-x-full',
        ].join(' ')}
      >
        <div className="border-b border-[var(--app-border)] px-6 pb-5 pt-6">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#24303a] shadow-lg shadow-slate-900/10 ring-1 ring-white/50">
              <School className="h-5 w-5 text-white" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-base font-semibold tracking-wide text-[var(--app-text-strong)]">School Operations</p>
              <p className="text-xs text-[var(--app-text-muted)]">{roleMeta.label}</p>
            </div>
          </div>

          <div className="mt-5 rounded-2xl border border-[var(--app-border)] bg-white/88 p-4 shadow-sm">
            <p className="text-xs uppercase tracking-[0.22em] text-[var(--app-text-muted)]">Signed In</p>
            <p className="mt-2 truncate text-sm font-medium text-[var(--app-text-strong)]">
              {user?.email ?? 'No active user'}
            </p>
          </div>
        </div>

        <nav className="flex-1 space-y-6 overflow-y-auto px-4 py-5">
          {roleMeta.sections.map((section) => (
            <div key={section.title}>
              <p className="px-3 text-[11px] font-semibold uppercase tracking-[0.24em] text-[var(--app-text-muted)]">
                {section.title}
              </p>
              <div className="mt-2 space-y-1.5">
                {section.items.map(({ href, label, icon: Icon, showUnread }) => {
                  const active = pathname === href || pathname.startsWith(`${href}/`);

                  return (
                    <Link
                      key={href}
                      href={href}
                      className={[
                        'group flex items-center gap-3 rounded-2xl px-3.5 py-3 text-sm font-medium transition-all duration-200',
                        active
                          ? 'bg-[#5a6a78] text-white shadow-lg shadow-slate-900/12'
                          : 'text-[var(--app-text)] hover:bg-white/88 hover:text-[var(--app-text-strong)] hover:shadow-sm',
                      ].join(' ')}
                    >
                      <span
                        className={[
                          'flex h-10 w-10 items-center justify-center rounded-2xl transition-colors',
                          active ? 'bg-white/15 text-white' : 'bg-[var(--app-accent-soft)] text-[var(--app-accent)] group-hover:bg-[var(--app-accent)] group-hover:text-white',
                        ].join(' ')}
                      >
                        <Icon className="h-[18px] w-[18px]" />
                      </span>
                      <span className="flex-1">{label}</span>
                      {showUnread && unread > 0 ? (
                        <span className="rounded-full bg-rose-500 px-2 py-0.5 text-xs font-semibold text-white">
                          {unread > 99 ? '99+' : unread}
                        </span>
                      ) : null}
                      <ChevronRight
                        className={[
                          'h-4 w-4 transition',
                          active ? 'translate-x-0 text-white/70' : '-translate-x-1 opacity-0 group-hover:translate-x-0 group-hover:opacity-100 group-hover:text-[var(--app-text-muted)]',
                        ].join(' ')}
                      />
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        <div className="border-t border-[var(--app-border)] px-4 py-4">
          <button
            type="button"
            onClick={logout}
            className="flex w-full items-center gap-3 rounded-2xl border border-[var(--app-border)] bg-white/88 px-3.5 py-3 text-sm font-medium text-[var(--app-text)] transition hover:border-red-300 hover:bg-red-50 hover:text-red-700"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-slate-100 text-[var(--app-text)]">
              <LogOut className="h-[18px] w-[18px]" />
            </span>
            <span className="flex-1 text-left">Log Out</span>
          </button>
        </div>
      </aside>
    </>
  );
}
