'use client';
import { useState } from 'react';
import Link from 'next/link';
import { requestPasswordReset } from '@/lib/api';
import { School, Mail, AlertCircle, CheckCircle } from 'lucide-react';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await requestPasswordReset(email);
      if (!res.ok) {
        const data = await res.json();
        setError(data?.message ?? 'Failed to request reset. Check your email address.');
      } else {
        setSuccess(true);
      }
    } catch {
      setError('Cannot connect to the server.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="w-full flex-1 min-h-screen flex items-center justify-center bg-[#dde6ed] p-4">
      <div className="relative bg-white/95 backdrop-blur-sm rounded-2xl shadow-2xl w-full max-w-md p-8">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-[#526d82] flex items-center justify-center shadow-lg shadow-slate-500/25">
            <School className="w-8 h-8 text-white" />
          </div>
        </div>

        {success ? (
          <div className="text-center">
            <CheckCircle className="w-16 h-16 text-emerald-500 mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-slate-900 mb-2">Email Sent</h1>
            <p className="text-slate-500 mb-6">A password reset code has been sent to your email.</p>
            <Link href={`/reset-password?email=${encodeURIComponent(email)}`} className="inline-block w-full bg-slate-100 hover:bg-slate-200 text-slate-800 font-semibold py-3 rounded-xl text-sm transition-colors mb-4">
              Enter Reset Code
            </Link>
          </div>
        ) : (
          <>
            <h1 className="text-2xl font-bold text-slate-900 text-center mb-1">Forgot Password</h1>
            <p className="text-sm text-slate-500 text-center mb-6">We&apos;ll send you a code to reset it.</p>

            {error && (
              <div className="flex items-start gap-3 bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl p-4 mb-6">
                <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" /><span>{error}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email Address" className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#526d82]" />
              </div>
              <button type="submit" disabled={loading} className="w-full bg-[#526d82] hover:bg-[#27374d] text-white font-semibold py-3 rounded-xl text-sm shadow-lg flex justify-center">
                {loading ? 'Sending...' : 'Send Reset Link'}
              </button>
            </form>
          </>
        )}
        <p className="mt-8 text-center text-sm text-slate-500">
          Remember it now? <Link href="/login" className="font-semibold text-[#526d82] hover:text-[#27374d]">Sign in here</Link>
        </p>
      </div>
    </div>
  );
}
