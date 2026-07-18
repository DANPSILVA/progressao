import Header from '@/components/Header';
import RegisterForm from '@/components/auth/RegisterForm';

export const metadata = {
  title: 'Criar conta — RubinTracker',
};

export default function RegisterPage() {
  return (
    <div>
      <Header />
      <main className="max-w-md mx-auto py-16 px-4">
        <RegisterForm />
      </main>
    </div>
  );
}
