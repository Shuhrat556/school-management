'use client';
import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { AlertCircle, Link2, Trash2, UsersRound } from 'lucide-react';
import { adminGetUsers, getStudentParents, linkStudentParent, unlinkStudentParent } from '@/lib/api';

const PARENT_ROLE = 3;
const relationships = ['Mother', 'Father', 'Guardian', 'Other'];

async function loadParentData(studentId) {
  const [links, users] = await Promise.all([getStudentParents(studentId), adminGetUsers()]);
  return {
    parents: links ?? [],
    accounts: (users ?? []).filter((user) => user.role === PARENT_ROLE),
  };
}

// Admin panel on the student page: which parent accounts may see this student's
// grades and attendance in the parent portal.
export default function StudentParentsPanel({ studentId }) {
  const [parents, setParents] = useState([]);
  const [accounts, setAccounts] = useState([]);
  const [selected, setSelected] = useState('');
  const [relationship, setRelationship] = useState('Mother');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  const apply = useCallback((data) => {
    setParents(data.parents);
    setAccounts(data.accounts);
  }, []);

  const reload = useCallback(async () => apply(await loadParentData(studentId)), [apply, studentId]);

  useEffect(() => {
    let active = true;
    loadParentData(studentId).then((data) => {
      if (active) apply(data);
    });
    return () => {
      active = false;
    };
  }, [apply, studentId]);

  const available = useMemo(
    () => accounts.filter((account) => !parents.some((parent) => parent.parentAuthUserId === account.id)),
    [accounts, parents],
  );

  async function handleLink(e) {
    e.preventDefault();
    const account = accounts.find((item) => item.id === selected);
    if (!account) return;

    setError('');
    setSaving(true);
    const res = await linkStudentParent(studentId, {
      parentAuthUserId: account.id,
      fullName: `${account.firstName ?? ''} ${account.lastName ?? ''}`.trim() || account.email,
      email: account.email,
      relationship,
    });
    setSaving(false);

    if (!res.ok) {
      setError('Could not link the parent account.');
      return;
    }
    setSelected('');
    await reload();
  }

  async function handleUnlink(parent) {
    if (!confirm(`Remove ${parent.fullName}'s access to this student?`)) return;
    const res = await unlinkStudentParent(studentId, parent.parentAuthUserId);
    if (!res.ok) {
      setError('Could not remove the parent link.');
      return;
    }
    await reload();
  }

  return (
    <section className="admin-section mt-6 space-y-4">
      <div className="flex items-center gap-2">
        <UsersRound className="h-5 w-5 text-slate-500" />
        <h2 className="text-lg font-semibold text-slate-900">Parents</h2>
      </div>
      <p className="text-sm text-slate-500">
        Linked parent accounts see this student&apos;s grades and attendance in the parent portal.
      </p>

      {error && (
        <div className="flex items-center gap-3 rounded-xl border border-red-100 bg-red-50 p-3 text-sm text-red-700">
          <AlertCircle className="h-4 w-4 shrink-0" />
          {error}
        </div>
      )}

      {parents.length === 0 ? (
        <p className="text-sm text-slate-400">No parent accounts linked yet.</p>
      ) : (
        <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200">
          {parents.map((parent) => (
            <li key={parent.id} className="flex items-center justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-medium text-slate-800">{parent.fullName}</p>
                <p className="truncate text-xs text-slate-500">
                  {[parent.relationship, parent.email].filter(Boolean).join(' · ')}
                </p>
              </div>
              <button
                type="button"
                onClick={() => handleUnlink(parent)}
                className="rounded-lg p-2 text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600"
                aria-label={`Unlink ${parent.fullName}`}
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </li>
          ))}
        </ul>
      )}

      {available.length > 0 ? (
        <form onSubmit={handleLink} className="grid gap-3 sm:grid-cols-[1fr_auto_auto]">
          <select value={selected} onChange={(e) => setSelected(e.target.value)} className="admin-input" required>
            <option value="">Choose a parent account…</option>
            {available.map((account) => (
              <option key={account.id} value={account.id}>
                {`${account.firstName ?? ''} ${account.lastName ?? ''}`.trim() || account.email} — {account.email}
              </option>
            ))}
          </select>
          <select value={relationship} onChange={(e) => setRelationship(e.target.value)} className="admin-input">
            {relationships.map((value) => (
              <option key={value} value={value}>{value}</option>
            ))}
          </select>
          <button type="submit" disabled={saving || !selected} className="admin-btn-primary disabled:opacity-50">
            <Link2 className="h-4 w-4" />
            Link
          </button>
        </form>
      ) : (
        <p className="text-sm text-slate-500">
          No unlinked parent accounts. Create one with the Parent role on the{' '}
          <Link href="/admin/users" className="font-medium text-slate-700 underline">Users</Link> page.
        </p>
      )}
    </section>
  );
}
