'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, MessageSquare, PenSquare, Send } from 'lucide-react';
import { useAuth } from '@/lib/auth';
import {
  getConversationMessages,
  getConversations,
  getMessageContacts,
  markConversationRead,
  sendConversationMessage,
  startConversation,
} from '@/lib/api';
import { formatRelativeTime, toArray } from '@/lib/student-portal';

// F9: one-to-one messages between teachers and students or parents of the same classes (D18).
export default function MessagesPage() {
  useAuth([1, 2, 3]); // Teachers, students and parents

  const [conversations, setConversations] = useState({ loading: true, items: [] });
  const [active, setActive] = useState(null);
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const [contacts, setContacts] = useState(null); // null = picker closed

  const loadConversations = useCallback(async () => {
    const items = await getConversations();
    setConversations({ loading: false, items: toArray(items) });
  }, []);

  useEffect(() => {
    getConversations().then((items) => setConversations({ loading: false, items: toArray(items) }));
  }, []);

  async function open(conversation) {
    setActive(conversation);
    setError('');
    const items = await getConversationMessages(conversation.id);
    setMessages(toArray(items));
    await markConversationRead(conversation.id);
    loadConversations();
  }

  async function send(e) {
    e.preventDefault();
    const body = draft.trim();
    if (!active || !body) return;
    setSending(true);
    const res = await sendConversationMessage(active.id, body);
    setSending(false);
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.message ?? 'The message could not be sent.');
      return;
    }
    setDraft('');
    setError('');
    setMessages(toArray(await getConversationMessages(active.id)));
    loadConversations();
  }

  async function openPicker() {
    setContacts(toArray(await getMessageContacts()));
  }

  async function startWith(contact) {
    setContacts(null);
    const res = await startConversation(contact);
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.message ?? 'The conversation could not be started.');
      return;
    }
    const conversation = await res.json();
    await loadConversations();
    open(conversation);
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-sm font-medium text-slate-500">Inbox</p>
          <h1 className="text-2xl font-semibold tracking-tight text-slate-950">Messages</h1>
        </div>
        <button type="button" onClick={openPicker} className="admin-btn-primary">
          <PenSquare className="h-4 w-4" />
          New message
        </button>
      </div>

      {contacts !== null ? (
        <div className="admin-card p-4">
          <p className="mb-3 text-sm font-semibold text-slate-700">Write to</p>
          {contacts.length === 0 ? (
            <p className="text-sm text-slate-500">There is no one you can write to yet. Teachers and families of the same classes can message each other.</p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {contacts.map((c) => (
                <li key={`${c.kind}-${c.teacherId ?? ''}-${c.studentId ?? ''}-${c.parentAuthUserId ?? ''}`}>
                  <button type="button" onClick={() => startWith(c)} className="flex w-full items-center justify-between px-2 py-3 text-left hover:bg-slate-50">
                    <span className="font-medium text-slate-900">{c.name}</span>
                    <span className="text-xs text-slate-500">{c.context ?? c.kind}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
          <button type="button" onClick={() => setContacts(null)} className="mt-3 text-sm text-slate-500 hover:text-slate-700">Cancel</button>
        </div>
      ) : null}

      {error ? (
        <div className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          <AlertCircle className="h-5 w-5 shrink-0" />
          {error}
        </div>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-[320px_1fr]">
        <ul className="admin-card divide-y divide-slate-100 overflow-hidden">
          {conversations.loading ? (
            <li className="p-6 text-sm text-slate-500">Loading…</li>
          ) : conversations.items.length === 0 ? (
            <li className="p-6 text-sm text-slate-500">No conversations yet.</li>
          ) : (
            conversations.items.map((c) => (
              <li key={c.id}>
                <button type="button" onClick={() => open(c)}
                  className={`flex w-full items-start gap-3 px-4 py-3 text-left hover:bg-slate-50 ${active?.id === c.id ? 'bg-slate-50' : ''}`}>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-slate-900">{c.title}</span>
                    <span className="block truncate text-xs text-slate-500">{c.lastMessage ?? c.subtitle}</span>
                  </span>
                  {c.unreadCount > 0 ? (
                    <span className="rounded-full bg-orange-500 px-2 py-0.5 text-xs font-semibold text-white">{c.unreadCount}</span>
                  ) : null}
                </button>
              </li>
            ))
          )}
        </ul>

        <section className="admin-card flex min-h-[420px] flex-col">
          {!active ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-2 p-10 text-sm text-slate-500">
              <MessageSquare className="h-8 w-8 text-slate-300" />
              Choose a conversation or start a new one.
            </div>
          ) : (
            <>
              <header className="border-b border-slate-100 px-5 py-3">
                <p className="font-semibold text-slate-900">{active.title}</p>
                {active.subtitle ? <p className="text-xs text-slate-500">{active.subtitle}</p> : null}
              </header>
              <div className="flex-1 space-y-2 overflow-y-auto p-5">
                {messages.length === 0 ? <p className="text-sm text-slate-400">No messages yet.</p> : null}
                {messages.map((m) => (
                  <div key={m.id} className={`flex ${m.isMine ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[75%] rounded-2xl px-4 py-2 text-sm ${m.isMine ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-800'}`}>
                      <p className="whitespace-pre-line">{m.body}</p>
                      <p className={`mt-1 text-[10px] ${m.isMine ? 'text-white/70' : 'text-slate-400'}`}>{formatRelativeTime(m.sentAt)}</p>
                    </div>
                  </div>
                ))}
              </div>
              <form onSubmit={send} className="flex gap-2 border-t border-slate-100 p-3">
                <textarea value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={2000} rows={2}
                  placeholder="Write a message" className="flex-1 resize-none rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                <button type="submit" disabled={sending || !draft.trim()} className="admin-btn-primary self-end disabled:opacity-50">
                  <Send className="h-4 w-4" />
                  Send
                </button>
              </form>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
