import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useAuth } from '../contexts/AuthContext'
import { Shield, Eye, EyeOff } from 'lucide-react'
import { toast } from 'sonner'

const loginSchema = z.object({
  email: z.string().email('Nieprawidłowy adres email'),
  password: z.string().min(1, 'Hasło jest wymagane'),
})

type LoginFormData = z.infer<typeof loginSchema>

export default function Login() {
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  const onSubmit = async (data: LoginFormData) => {
    setIsLoading(true)
    try {
      await login(data.email, data.password)
      toast.success('Zalogowano pomyślnie!')
      navigate('/')
    } catch (error: any) {
      const message = error.response?.data?.error || 'Błąd logowania'
      toast.error(message)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 flex items-center justify-center rounded-full bg-primary">
            <Shield className="h-8 w-8 text-primary-foreground" />
          </div>
          <h2 className="mt-6 text-3xl font-bold tracking-tight text-foreground">
            Zaloguj się do Safe-Spac
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Zarządzaj swoim VPN i TeamSpeak w jednym miejscu
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)}>
          <div className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-foreground">
                Adres email
              </label>
              <input
                {...register('email')}
                type="email"
                id="email"
                className="input mt-1"
                placeholder="twoj@email.com"
                disabled={isLoading}
              />
              {errors.email && (
                <p className="mt-1 text-sm text-destructive">{errors.email.message}</p>
              )}
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-foreground">
                Hasło
              </label>
              <div className="relative mt-1">
                <input
                  {...register('password')}
                  type={showPassword ? 'text' : 'password'}
                  id="password"
                  className="input pr-10"
                  placeholder="••••••••"
                  disabled={isLoading}
                />
                <button
                  type="button"
                  className="absolute inset-y-0 right-0 pr-3 flex items-center"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? (
                    <EyeOff className="h-5 w-5 text-muted-foreground" />
                  ) : (
                    <Eye className="h-5 w-5 text-muted-foreground" />
                  )}
                </button>
              </div>
              {errors.password && (
                <p className="mt-1 text-sm text-destructive">{errors.password.message}</p>
              )}
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={isLoading}
              className="btn-primary w-full"
            >
              {isLoading ? 'Logowanie...' : 'Zaloguj się'}
            </button>
          </div>

          <div className="text-center">
            <p className="text-sm text-muted-foreground">
              Nie masz konta?{' '}
              <Link
                to="/register"
                className="font-medium text-primary hover:text-primary/80 transition-colors"
              >
                Zarejestruj się
              </Link>
            </p>
          </div>
        </form>
      </div>
    </div>
  )
}