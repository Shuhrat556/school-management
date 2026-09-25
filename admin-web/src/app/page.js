'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getUser } from '@/lib/auth';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    const user = getUser();
    if (!user) {
      router.replace('/login');
      return;
    }
    
    // Redirect based on role (Admin=4, Teacher=1, Student=2, Parent=3)
    if (user.role === 4) {
      router.replace('/admin/dashboard');
    } else if (user.role === 1) {
      router.replace('/teacher/dashboard');
    } else if (user.role === 2) {
      router.replace('/student/dashboard');
    } else if (user.role === 3) {
      router.replace('/parent/dashboard');
    } else {
      router.replace('/login');
    }
  }, [router]);

  return null;
}
