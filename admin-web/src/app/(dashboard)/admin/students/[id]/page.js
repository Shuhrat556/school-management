'use client';
import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { getStudent, updateStudent } from '@/lib/api';
import StudentParentsPanel from '@/components/StudentParentsPanel';
import { GraduationCap, ArrowLeft, AlertCircle, Save, User, Phone, Calendar, MapPin, Users, Mail, Power } from 'lucide-react';

const inputCls = 'admin-input';

function Field({ label, required, icon, children }) {
  return (
    <div>
      <label className="flex items-center gap-1.5 text-sm font-semibold text-slate-700 mb-1.5">
        {icon && <span className="text-slate-400">{icon}</span>}
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );
}

export default function EditStudentPage() {
  useAuth();

  const router = useRouter();
  const { id } = useParams();

  const [form, setForm] = useState(null);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getStudent(id).then((data) => {
      if (data) {
        setForm({
          firstName:   data.firstName ?? '',
          lastName:    data.lastName ?? '',
          gender:      data.gender ?? '',
          dateOfBirth: data.dateOfBirth ? data.dateOfBirth.slice(0, 10) : '',
          phone:       data.phone ?? '',
          address:     data.address ?? '',
          email:       data.email ?? '',
          isActive:    data.isActive ?? true,
        });
      }
      setLoading(false);
    });
  }, [id]);

  function set(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      const payload = {
        firstName: form.firstName,
        lastName: form.lastName,
        gender: form.gender || null,
        dateOfBirth: form.dateOfBirth ? form.dateOfBirth : null,
        phone: form.phone || null,
        address: form.address || null,
        email: form.email || null,
        isActive: form.isActive,
      };
      const res = await updateStudent(id, payload);
      if (res?.ok) {
        router.push('/admin/students');
      } else {
        const data = await res.json().catch(() => ({}));
        setError(data?.message ?? data?.error ?? 'Failed to update student.');
      }
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="max-w-lg">
        <div className="bg-white rounded-2xl border border-slate-100 p-12 text-center">
          <div className="w-8 h-8 border-2 border-amber-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-slate-500 text-sm">Loading student...</p>
        </div>
      </div>
    );
  }

  if (!form) {
    return (
      <div className="max-w-lg">
        <div className="flex items-center gap-3 bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl p-4">
          <AlertCircle className="w-5 h-5 shrink-0" />
          Student not found.
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-lg admin-page">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Link href="/admin/students" className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-lg transition-colors">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div className="admin-header-icon">
          <GraduationCap className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Edit Student</h1>
          <p className="text-sm text-slate-500">{form.firstName} {form.lastName}</p>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-3 bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl p-4 mb-4">
          <AlertCircle className="w-5 h-5 shrink-0" />
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="admin-section space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <Field label="First Name" required icon={<User className="w-4 h-4" />}>
            <input type="text" required value={form.firstName}
              onChange={(e) => set('firstName', e.target.value)} className={inputCls} />
          </Field>
          <Field label="Last Name" required icon={<User className="w-4 h-4" />}>
            <input type="text" required value={form.lastName}
              onChange={(e) => set('lastName', e.target.value)} className={inputCls} />
          </Field>
        </div>

        <Field label="Gender" icon={<Users className="w-4 h-4" />}>
          <select value={form.gender} onChange={(e) => set('gender', e.target.value)} className={inputCls}>
            <option value="">Select gender...</option>
            <option value="Male">Male</option>
            <option value="Female">Female</option>
            <option value="Other">Other</option>
          </select>
        </Field>

        <Field label="Date of Birth" icon={<Calendar className="w-4 h-4" />}>
          <input type="date" value={form.dateOfBirth}
            onChange={(e) => set('dateOfBirth', e.target.value)} className={inputCls} />
        </Field>

        <Field label="Phone" icon={<Phone className="w-4 h-4" />}>
          <input type="text" value={form.phone}
            onChange={(e) => set('phone', e.target.value)} placeholder="+1 234 567 890" className={inputCls} />
        </Field>

        <Field label="Address" icon={<MapPin className="w-4 h-4" />}>
          <input type="text" value={form.address}
            onChange={(e) => set('address', e.target.value)} placeholder="123 Main St, City" className={inputCls} />
        </Field>

        <Field label="Email" icon={<Mail className="w-4 h-4" />}>
          <input type="email" value={form.email}
            onChange={(e) => set('email', e.target.value)} placeholder="student@school.com" className={inputCls} />
        </Field>

        <Field label="Status" icon={<Power className="w-4 h-4" />}>
          <button
            type="button"
            onClick={() => set('isActive', !form.isActive)}
            className={`w-full px-4 py-2.5 rounded-lg font-medium text-sm transition-all ${
              form.isActive
                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100'
                : 'bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200'
            }`}
          >
            {form.isActive ? '✓ Active' : '✕ Inactive'}
          </button>
        </Field>

        <div className="flex gap-3 pt-3">
          <button type="submit" disabled={saving} className="admin-btn-primary disabled:opacity-50">
            {saving ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            {saving ? 'Saving...' : 'Update Student'}
          </button>
          <button type="button" onClick={() => router.push('/admin/students')}
            className="text-slate-600 hover:text-slate-800 text-sm font-medium px-5 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 transition-colors">
            Cancel
          </button>
        </div>
      </form>

      <StudentParentsPanel studentId={id} />
    </div>
  );
}
