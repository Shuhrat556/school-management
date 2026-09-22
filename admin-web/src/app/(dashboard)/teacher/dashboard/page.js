'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useAuth, getUser } from '@/lib/auth';
import { getClassrooms, getStudents, getSubjects } from '@/lib/api';
import { School, GraduationCap, ClipboardCheck, BarChart3, TrendingUp, Activity, ArrowRight } from 'lucide-react';

export default function TeacherDashboard() {
  useAuth([1]);

  const [user, setUser] = useState(null);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setUser(getUser());
    async function load() {
      const [classrooms, students, subjects] = await Promise.all([
        getClassrooms(1, 1),
        getStudents(1, 1),
        getSubjects(),
      ]);
      setStats({
        classrooms: classrooms?.totalCount ?? classrooms?.items?.length ?? 0,
        students:   students?.totalCount   ?? students?.items?.length   ?? 0,
        subjects:   subjects?.length ?? subjects?.items?.length ?? 0,
      });
      setLoading(false);
    }
    load();
  }, []);

  const cards = [
    { label: 'Assigned Classes', value: stats?.classrooms, href: '/teacher/classrooms', icon: School,         color: '#27374d', shadow: 'shadow-slate-500/20' },
    { label: 'Total Students',   value: stats?.students,   href: '/teacher/classrooms', icon: GraduationCap,  color: '#526d82', shadow: 'shadow-slate-500/20' },
    { label: 'Active Subjects',  value: stats?.subjects,   href: '/teacher/grades',     icon: BarChart3,      color: '#9db2bf', shadow: 'shadow-slate-500/20' },
  ];

  return (
    <div className="p-8 max-w-7xl mx-auto relative min-h-full">
      {/* Decorative background blobs */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden -z-10 pointer-events-none">
        <div className="absolute top-[-10%] left-[-5%] w-96 h-96 bg-[#dde6ed] rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-[-10%] right-[-5%] w-96 h-96 bg-[#9db2bf] rounded-full blur-3xl animate-pulse delay-1000" />
      </div>

      {/* Header */}
      <div className="mb-10 flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 className="text-4xl font-extrabold text-[#27374d] tracking-tight mb-2">
            Welcome back, {user?.firstName || user?.email?.split('@')[0] || 'Teacher'} 👋
          </h1>
          <p className="text-slate-500 text-lg font-medium">
            Here&apos;s an overview of your academic activities today.
          </p>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
        {cards.map(({ label, value, href, icon: Icon, gradient, shadow }, idx) => (
          <Link
            key={label}
            href={href}
            className={`group relative overflow-hidden bg-white/70 backdrop-blur-xl rounded-3xl border border-white/50 p-6 shadow-xl shadow-slate-200/50 hover:shadow-2xl hover:-translate-y-1.5 transition-all duration-500`}
            style={{ animationDelay: `${idx * 100}ms` }}
          >
            <div className="relative z-10 flex items-start justify-between">
              <div className="bg-[#526d82] rounded-2xl w-14 h-14 flex items-center justify-center shadow-lg shadow-slate-500/20 transform group-hover:scale-110 group-hover:rotate-3 transition-transform duration-500">
                <Icon className="w-7 h-7 text-white" />
              </div>
              <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center -mr-2 -mt-2 opacity-0 group-hover:opacity-100 transition-all duration-300 transform translate-x-4 group-hover:translate-x-0">
                <ArrowRight className="w-5 h-5 text-slate-400" />
              </div>
            </div>
            <div className="mt-6 relative z-10">
              <p className="text-5xl font-black text-slate-800 tracking-tight">
                {loading ? <span className="animate-pulse text-slate-300">—</span> : value}
              </p>
              <p className="text-sm font-semibold text-slate-500 uppercase tracking-wider mt-2">{label}</p>
            </div>
            {/* Subtle background gradient on hover */}
            <div className="absolute inset-0 bg-[#526d82] opacity-0 group-hover:opacity-5 transition-opacity duration-500" />
          </Link>
        ))}
      </div>

      {/* Quick Actions Panel */}
      <div className="bg-white/70 backdrop-blur-xl rounded-3xl border border-white/50 shadow-xl shadow-slate-200/50 p-8 relative overflow-hidden">
        {/* Decorative pattern */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-[#dde6ed] pointer-events-none" />
        
        <div className="flex items-center gap-3 mb-8 relative z-10">
          <div className="p-2.5 bg-[#e6eef3] text-[#526d82] rounded-xl">
            <Activity className="w-6 h-6" />
          </div>
          <h2 className="text-xl font-bold text-slate-800">Quick Tools</h2>
        </div>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 relative z-10">
          <Link href="/teacher/attendance" className="group flex items-center gap-4 p-5 bg-white rounded-2xl border border-slate-100 hover:border-[#9db2bf] hover:bg-[#f4f8fb]/70 hover:shadow-lg hover:shadow-slate-500/10 transition-all duration-300">
            <div className="bg-[#e6eef3] text-[#526d82] p-3 rounded-xl group-hover:bg-[#526d82] group-hover:text-white transition-colors duration-300">
              <ClipboardCheck className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-slate-800">Record Attendance</h3>
              <p className="text-xs text-slate-500 mt-0.5">Mark daily presence</p>
            </div>
          </Link>
          
          <Link href="/teacher/grades" className="group flex items-center gap-4 p-5 bg-white rounded-2xl border border-slate-100 hover:border-[#9db2bf] hover:bg-[#f4f8fb]/70 hover:shadow-lg hover:shadow-slate-500/10 transition-all duration-300">
            <div className="bg-[#e6eef3] text-[#526d82] p-3 rounded-xl group-hover:bg-[#27374d] group-hover:text-white transition-colors duration-300">
              <BarChart3 className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-slate-800">Input Grades</h3>
              <p className="text-xs text-slate-500 mt-0.5">Evaluate assignments</p>
            </div>
          </Link>
          
          <Link href="/teacher/classrooms" className="group flex items-center gap-4 p-5 bg-white rounded-2xl border border-slate-100 hover:border-[#9db2bf] hover:bg-[#f4f8fb]/70 hover:shadow-lg hover:shadow-slate-500/10 transition-all duration-300">
            <div className="bg-[#e6eef3] text-[#526d82] p-3 rounded-xl group-hover:bg-[#526d82] group-hover:text-white transition-colors duration-300">
              <School className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-slate-800">Browse Classrooms</h3>
              <p className="text-xs text-slate-500 mt-0.5">View your assigned classes</p>
            </div>
          </Link>
        </div>
      </div>
    </div>
  );
}
