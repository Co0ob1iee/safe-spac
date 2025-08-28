import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Shield, Users, Headphones, Activity, Download, Settings } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'

const Dashboard: React.FC = () => {
  const { user, isAdmin } = useAuth()

  const stats = [
    {
      title: 'Status VPN',
      value: user?.vpnConfig?.enabled ? 'Aktywny' : 'Nieaktywny',
      icon: Shield,
      color: user?.vpnConfig?.enabled ? 'text-green-600' : 'text-red-600',
      bgColor: user?.vpnConfig?.enabled ? 'bg-green-100' : 'bg-red-100'
    },
    {
      title: 'Użytkownicy online',
      value: '12',
      icon: Users,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100'
    },
    {
      title: 'TeamSpeak',
      value: 'Online',
      icon: Headphones,
      color: 'text-green-600',
      bgColor: 'bg-green-100'
    },
    {
      title: 'System',
      value: 'Operacyjny',
      icon: Activity,
      color: 'text-green-600',
      bgColor: 'bg-green-100'
    }
  ]

  const quickActions = [
    {
      title: 'Konfiguracja VPN',
      description: 'Pobierz lub zaktualizuj konfigurację VPN',
      icon: Download,
      href: '/vpn',
      color: 'text-blue-600',
      bgColor: 'bg-blue-100'
    },
    {
      title: 'TeamSpeak',
      description: 'Zarządzaj kanałami i użytkownikami TS',
      icon: Headphones,
      href: '/teamspeak',
      color: 'text-purple-600',
      bgColor: 'bg-purple-100'
    }
  ]

  if (isAdmin) {
    quickActions.push(
      {
        title: 'Zarządzanie użytkownikami',
        description: 'Zatwierdzaj rejestracje i zarządzaj kontami',
        icon: Users,
        href: '/users',
        color: 'text-green-600',
        bgColor: 'bg-green-100'
      },
      {
        title: 'Panel administracyjny',
        description: 'Zaawansowane ustawienia systemu',
        icon: Settings,
        href: '/admin',
        color: 'text-orange-600',
        bgColor: 'bg-orange-100'
      }
    )
  }

  return (
    <div className="space-y-6">
      {/* Welcome header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-foreground">
            Witaj, {user?.username}!
          </h1>
          <p className="text-muted-foreground mt-2">
            Oto przegląd Twojego konta i systemu Safe-Spac
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <div className="h-3 w-3 rounded-full bg-green-500"></div>
          <span className="text-sm text-muted-foreground">System online</span>
        </div>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, index) => {
          const Icon = stat.icon
          return (
            <Card key={index}>
              <CardContent className="p-6">
                <div className="flex items-center space-x-4">
                  <div className={`p-3 rounded-lg ${stat.bgColor}`}>
                    <Icon className={`h-6 w-6 ${stat.color}`} />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">
                      {stat.title}
                    </p>
                    <p className="text-2xl font-bold text-foreground">
                      {stat.value}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Quick actions */}
      <div>
        <h2 className="text-xl font-semibold text-foreground mb-4">
          Szybkie akcje
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {quickActions.map((action, index) => {
            const Icon = action.icon
            return (
              <Card key={index} className="hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center space-x-3">
                    <div className={`p-2 rounded-lg ${action.bgColor}`}>
                      <Icon className={`h-5 w-5 ${action.color}`} />
                    </div>
                    <CardTitle className="text-lg">{action.title}</CardTitle>
                  </div>
                  <CardDescription>{action.description}</CardDescription>
                </CardHeader>
                <CardContent>
                  <Button 
                    variant="outline" 
                    className="w-full"
                    onClick={() => window.location.href = action.href}
                  >
                    Przejdź
                  </Button>
                </CardContent>
              </Card>
            )
          })}
        </div>
      </div>

      {/* System info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Informacje o koncie</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Email:</span>
              <span className="font-medium">{user?.email}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Rola:</span>
              <span className="font-medium capitalize">{user?.role}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Status:</span>
              <span className={`font-medium capitalize ${
                user?.status === 'active' ? 'text-green-600' : 
                user?.status === 'pending' ? 'text-yellow-600' : 'text-red-600'
              }`}>
                {user?.status === 'active' ? 'Aktywny' : 
                 user?.status === 'pending' ? 'Oczekujący' : 'Zawieszony'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Data utworzenia:</span>
              <span className="font-medium">
                {new Date(user?.createdAt || '').toLocaleDateString('pl-PL')}
              </span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Status VPN</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {user?.vpnConfig ? (
              <>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status:</span>
                  <span className={`font-medium ${
                    user.vpnConfig.enabled ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {user.vpnConfig.enabled ? 'Aktywny' : 'Nieaktywny'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Adres IP:</span>
                  <span className="font-medium font-mono">{user.vpnConfig.ipAddress}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Klucz publiczny:</span>
                  <span className="font-medium font-mono text-xs truncate max-w-32">
                    {user.vpnConfig.publicKey}
                  </span>
                </div>
              </>
            ) : (
              <div className="text-center py-4">
                <Shield className="h-12 w-12 text-muted-foreground mx-auto mb-2" />
                <p className="text-muted-foreground">
                  Konfiguracja VPN nie została jeszcze utworzona
                </p>
                <Button 
                  variant="outline" 
                  className="mt-3"
                  onClick={() => window.location.href = '/vpn'}
                >
                  Skonfiguruj VPN
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Recent activity */}
      <Card>
        <CardHeader>
          <CardTitle>Ostatnia aktywność</CardTitle>
          <CardDescription>
            Ostatnie działania w systemie
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex items-center space-x-3 p-3 bg-muted/50 rounded-lg">
              <div className="h-2 w-2 rounded-full bg-green-500"></div>
              <span className="text-sm text-muted-foreground">
                Zalogowano do systemu
              </span>
              <span className="text-xs text-muted-foreground ml-auto">
                {new Date().toLocaleTimeString('pl-PL')}
              </span>
            </div>
            {user?.vpnConfig?.enabled && (
              <div className="flex items-center space-x-3 p-3 bg-muted/50 rounded-lg">
                <div className="h-2 w-2 rounded-full bg-blue-500"></div>
                <span className="text-sm text-muted-foreground">
                  VPN został aktywowany
                </span>
                <span className="text-xs text-muted-foreground ml-auto">
                  Dzisiaj
                </span>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default Dashboard
