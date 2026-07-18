import React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';

const schema = z.object({
  name: z.string().min(1)
});

export default function PlayerForm() {
  const { register, handleSubmit } = useForm({ resolver: zodResolver(schema) });
  const onSubmit = (data: any) => console.log(data);

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
      <input {...register('name')} className="input" placeholder="Nome do personagem" />
      <button type="submit" className="px-3 py-2 bg-sky-600 text-white rounded">Salvar</button>
    </form>
  );
}
