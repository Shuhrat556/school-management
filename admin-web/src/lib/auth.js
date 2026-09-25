'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

// Returns the stored user object or null
export function getUser() {
  if (typeof window === 'undefined') return null;
  try {
    return JSON.parse(localStorage.getItem('user'));
  } catch {
    return null;
  }
}

export function getToken() {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('token');
}

import { logoutUser } from './api';

export async function logout() {
  try {
    await logoutUser();
  } catch {}
  localStorage.removeItem('token');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('user');
  window.location.href = '/login';
}

// Hook — redirect to /login if not authenticated or not authorized
export function useAuth(allowedRoles = []) {
  const router = useRouter();
  useEffect(() => {
    const token = localStorage.getItem('token');
    const userString = localStorage.getItem('user');
    
    if (!token || !userString) {
      router.replace('/login');
      return;
    }

    try {
      const user = JSON.parse(userString);
      if (allowedRoles.length > 0 && !allowedRoles.includes(user.role)) {
        if (user.role === 4) router.replace('/admin/dashboard');
        else if (user.role === 1) router.replace('/teacher/dashboard');
        else if (user.role === 2) router.replace('/student/dashboard');
        else if (user.role === 3) router.replace('/parent/dashboard');
        else router.replace('/login');
      }
    } catch {
      router.replace('/login');
    }
  }, [router]); // allow empty array, don't re-trigger on allowedRoles change if hardcoded
}
