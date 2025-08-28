import React, { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { Button } from '../components/ui/Button'
import { Input } from '../components/ui/Input'
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '../components/ui/Card'
import { Shield, AlertCircle, CheckCircle } from 'lucide-react'
import { toast } from 'sonner'

const Register: React.FC = () => {
  const [formData, setFormData] = useState({
    email: '',
    username: '',
    password: '',
    confirmPassword: '',
    inviteToken: ''
  })
  const [isLoading, setIsLoading] = useState(false)
  const [errors, setErrors] = useState<{ [key: string]: string }>({})
  const [isSuccess, setIsSuccess] = useState(false)
  
  const { register } = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  
  // Pobierz token z URL jeśli istnieje
  React.useEffect(() => {
    const token = searchParams.get('token')
    if (token) {
      setFormData(prev => ({ ...prev, inviteToken: token }))
    }
  }, [searchParams])

  const validateForm = () => {
    const newErrors: { [key: string]: string } = {}
    
    if (!formData.email) {
      newErrors.email = 'Email jest wymagany'
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Nieprawidłowy format email'
    }
    
    if (!formData.username) {
      newErrors.username = 'Nazwa użytkownika jest wymagana'
    } else if (formData.username.length < 3) {
      newErrors.username = 'Nazwa użytkownika musi mieć co najmniej 3 znaki'
    }
    
    if (!formData.password) {
      newErrors.password = 'Hasło jest wymagane'
    } else if (formData.password.length < 8) {
      newErrors.password = 'Hasło musi mieć co najmniej 8 znaków'
    }
    
    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Hasła nie są identyczne'
    }
    
    if (!formData.inviteToken) {
      newErrors.inviteToken = 'Token zaproszenia jest wymagany'
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
      await register({
        email: formData.email,
        username: formData.username,
        password: formData.password,
        inviteToken: formData.inviteToken
      })
      
      setIsSuccess(true)
      toast.success('Rejestracja zakończona pomyślnie!')
      
      // Przekieruj do logowania po 3 sekundach
      setTimeout(() => {
        navigate('/login')
      }, 3000)
      
    } catch (error: any) {
      console.error('Błąd rejestracji:', error)
      
      if (error.response?.status === 400) {
        if (error.response.data.error) {
          setErrors({ general: error.response.data.error })
        }
      } else if (error.response?.data?.error) {
        setErrors({ general: error.response.data.error })
      } else {
        setErrors({ general: 'Wystąpił błąd podczas rejestracji. Spróbuj ponownie.' })
      }
    } finally {
      setIsLoading(false)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    // Wyczyść błąd dla tego pola
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }))
    }
  }

  if (isSuccess) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <div className="w-full max-w-md text-center">
          <div className="flex justify-center mb-4">
            <div className="h-16 w-16 rounded-full bg-green-100 flex items-center justify-center">
              <CheckCircle className="h-8 w-8 text-green-600" />
            </div>
          </div>
          <h1 className="text-2xl font-bold text-foreground mb-2">
            Rejestracja zakończona!
          </h1>
          <p className="text-muted-foreground mb-6">
            Twoje konto zostało utworzone i oczekuje na zatwierdzenie przez administratora.
            Zostaniesz przekierowany do strony logowania.
          </p>
          <Button onClick={() => navigate('/login')}>
            Przejdź do logowania
          </Button>
        </div>
      </div>
    )
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
            Utwórz nowe konto
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Rejestracja</CardTitle>
            <CardDescription>
              Wypełnij formularz, aby utworzyć konto
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
                value={formData.email}
                onChange={(e) => handleInputChange('email', e.target.value)}
                error={errors.email}
                required
              />
              
              <Input
                type="text"
                label="Nazwa użytkownika"
                placeholder="twoja_nazwa"
                value={formData.username}
                onChange={(e) => handleInputChange('username', e.target.value)}
                error={errors.username}
                required
              />
              
              <Input
                type="password"
                label="Hasło"
                placeholder="Twoje hasło"
                value={formData.password}
                onChange={(e) => handleInputChange('password', e.target.value)}
                error={errors.password}
                required
              />
              
              <Input
                type="password"
                label="Potwierdź hasło"
                placeholder="Potwierdź hasło"
                value={formData.confirmPassword}
                onChange={(e) => handleInputChange('confirmPassword', e.target.value)}
                error={errors.confirmPassword}
                required
              />
              
              <Input
                type="text"
                label="Token zaproszenia"
                placeholder="Wprowadź token zaproszenia"
                value={formData.inviteToken}
                onChange={(e) => handleInputChange('inviteToken', e.target.value)}
                error={errors.inviteToken}
                helperText="Token zaproszenia jest wymagany do rejestracji"
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
                Zarejestruj się
              </Button>
              
              <div className="text-center text-sm text-muted-foreground">
                Masz już konto?{' '}
                <Link 
                  to="/login" 
                  className="text-primary hover:underline font-medium"
                >
                  Zaloguj się
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

export default Register
