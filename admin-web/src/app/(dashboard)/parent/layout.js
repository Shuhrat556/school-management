'use client';
import { useAuth } from '@/lib/auth';

export default function ParentLayout({ children }) {
  useAuth([3]); // Only Parent
  return <>{children}</>;
}
