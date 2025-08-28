import React, { useState } from 'react'
import { Link, useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { Button } from '../components/ui/Button'
import { Input } from '../components/ui/Input'
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '../components/ui/Card'
import { Shield, AlertCircle } from 'lucide-react'
import { toast } from 'sonner'

const Login: React.FC = () => {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [errors, setErrors] = useState<{ email?: string; password?: string; general?: string }>({})
  
  const { login } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  
  const from = location.state?.from?.pathname || '/'

  const validateForm = () => {
    const newErrors: { email?: string; password?: string } = {}
    
    if (!email) {
      newErrors.email = 'Email jest wymagany'
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      newErrors.email = 'Nieprawidłowy format email'
    }
    
    if (!password) {
      newErrors.password = 'Hasło jest wymagane'
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) return
    
    setIsLoading(true)
    setErrors({})
    
    try {
      await login(email, password)
      toast.success('Zalogowano pomyślnie!')
      navigate(from, { replace: true })
    } catch (error: any) {
      console.error('Błąd logowania:', error)
      
      if (error.response?.status === 401) {
        setErrors({ general: 'Nieprawidłowy email lub hasło' })
      } else if (error.response?.data?.error) {
        setErrors({ general: error.response.data.error })
      } else {
        setErrors({ general: 'Wystąpił błąd podczas logowania. Spróbuj ponownie.' })
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="h-16 w-16 rounded-full bg-primary flex items-center justify-center">
              <Shield className="h-8 w-8 text-primary-foreground" />
            </div>
          </div>
          <h1 className="text-3xl font-bold text-foreground">Safe-Spac</h1>
          <p className="text-muted-foreground mt-2">
            Zaloguj się do swojego konta
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Logowanie</CardTitle>
            <CardDescription>
              Wprowadź swoje dane logowania, aby uzyskać dostęp
            </CardDescription>
          </CardHeader>
          
          <form onSubmit={handleSubmit}>
            <CardContent className="space-y-4">
              {errors.general && (
                <div className="flex items-center space-x-2 p-3 bg-destructive/10 border border-destructive/20 rounded-md">
                  <AlertCircle className="h-4 w-4 text-destructive flex-shrink-0" />
                  <span className="text-sm text-destructive">{errors.general}</span>
                </div>
              )}
              
                             <Input
                 type="email"
                 label="Email"
                 placeholder="twoj@email.com"
                 value={email}
                 onChange={(e) => setEmail(e.target.value)}
                 error={errors.email}
                 required
               />
              
                             <Input
                 type="password"
                 label="Hasło"
                 placeholder="Twoje hasło"
                 value={password}
                 onChange={(e) => setPassword(e.target.value)}
                 error={errors.password}
                 required
               />
            </CardContent>
            
            <CardFooter className="flex flex-col space-y-4">
              <Button 
                type="submit" 
                className="w-full" 
                isLoading={isLoading}
                disabled={isLoading}
              >
                Zaloguj się
              </Button>
              
              <div className="text-center text-sm text-muted-foreground">
                Nie masz konta?{' '}
                <Link 
                  to="/register" 
                  className="text-primary hover:underline font-medium"
                >
                  Zarejestruj się
                </Link>
              </div>
            </CardFooter>
          </form>
        </Card>
        
        <div className="text-center mt-6">
          <p className="text-xs text-muted-foreground">
            Safe-Spac - Bezpieczna platforma VPN
          </p>
        </div>
      </div>
    </div>
  )
}

export default Login
