import Header from '@/components/Header';
import LoginForm from '@/components/auth/LoginForm';

export const metadata = {
  title: 'Entrar — RubinTracker',
};

export default function LoginPage() {
  return (
    <div>
      <Header />
      <main className="max-w-md mx-auto py-16 px-4">
        <LoginForm />
      </main>
    </div>
  );
}
