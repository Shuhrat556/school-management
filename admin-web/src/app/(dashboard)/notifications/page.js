'use client';

import { useEffect, useState } from 'react';
import { Bell, BarChart3, CalendarX2, CheckCheck, Megaphone } from 'lucide-react';
import { useAuth } from '@/lib/auth';
import { getNotifications, markAllNotificationsRead, markNotificationRead } from '@/lib/api';
import StudentEmptyState from '@/components/StudentEmptyState';
import { formatRelativeTime, toArray } from '@/lib/student-portal';

const typeIcons = { Grade: BarChart3, Attendance: CalendarX2, Announcement: Megaphone };

export default function NotificationsPage() {
  useAuth([2, 3]); // Students and parents

  const [state, setState] = useState({ loading: true, error: '', items: [] });

  useEffect(() => {
    let active = true;
    getNotifications({ take: 100 }).then((items) => {
      if (!active) return;
      setState(items === null
        ? { loading: false, error: 'Could not load notifications.', items: [] }
        : { loading: false, error: '', items: toArray(items) });
    });
    return () => {
      active = false;
    };
  }, []);

  function markLocallyRead(predicate) {
    const now = new Date().toISOString();
    setState((current) => ({
      ...current,
      items: current.items.map((item) => (predicate(item) && !item.readAt ? { ...item, readAt: now, isRead: true } : item)),
    }));
  }

  async function handleOpen(item) {
    if (item.readAt) return;
    const res = await markNotificationRead(item.id);
    if (res.ok) markLocallyRead((candidate) => candidate.id === item.id);
  }

  async function handleReadAll() {
    const res = await markAllNotificationsRead();
    if (res.ok) markLocallyRead(() => true);
  }

  const unread = state.items.filter((item) => !item.readAt).length;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-sm font-medium text-slate-500">Updates</p>
          <h1 className="text-2xl font-semibold tracking-tight text-slate-950">Notifications</h1>
        </div>
        {unread > 0 ? (
          <button type="button" onClick={handleReadAll} className="admin-btn-secondary">
            <CheckCheck className="h-4 w-4" />
            Mark all as read
          </button>
        ) : null}
      </div>

      {state.loading ? (
        <div className="flex h-40 items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-300 border-t-slate-700" />
        </div>
      ) : state.error ? (
        <div className="rounded-xl border border-red-100 bg-red-50 p-4 text-sm text-red-700">{state.error}</div>
      ) : state.items.length === 0 ? (
        <StudentEmptyState icon={Bell} title="No notifications yet" description="New grades, absences and class announcements will show up here." />
      ) : (
        <ul className="divide-y divide-slate-100 overflow-hidden rounded-2xl border border-slate-200 bg-white">
          {state.items.map((item) => {
            const Icon = typeIcons[item.type] ?? Bell;
            return (
              <li key={item.id}>
                <button
                  type="button"
                  onClick={() => handleOpen(item)}
                  className={`flex w-full items-start gap-4 px-5 py-4 text-left transition-colors hover:bg-slate-50 ${item.readAt ? '' : 'bg-sky-50/60'}`}
                >
                  <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-600">
                    <Icon className="h-4 w-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex flex-wrap items-center gap-x-2">
                      <span className={`text-sm ${item.readAt ? 'font-medium text-slate-700' : 'font-semibold text-slate-900'}`}>{item.title}</span>
                      {item.studentName ? <span className="text-xs text-slate-500">· {item.studentName}</span> : null}
                    </span>
                    <span className="mt-1 block text-sm text-slate-600">{item.body}</span>
                    <span className="mt-1 block text-xs text-slate-400">{formatRelativeTime(item.createdAt)}</span>
                  </span>
                  {!item.readAt ? <span className="mt-2 h-2 w-2 shrink-0 rounded-full bg-sky-500" aria-label="Unread" /> : null}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
