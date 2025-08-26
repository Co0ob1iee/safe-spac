import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../contexts/AuthContext'
import { apiClient } from '../lib/api'
import { 
  Users, 
  Shield, 
  Headphones, 
  Activity, 
  TrendingUp, 
  AlertCircle,
  CheckCircle,
  Clock
} from 'lucide-react'

export default function Dashboard() {
  const { user, isAdmin } = useAuth()

  const { data: vpnStatus } = useQuery({
    queryKey: ['vpn-status'],
    queryFn: () => apiClient.healthCheck(),
    refetchInterval: 30000, // Refresh every 30 seconds
  })

  const { data: users } = useQuery({
    queryKey: ['users'],
    queryFn: () => apiClient.getUsers(),
    enabled: isAdmin,
  })

  const stats = [
    {
      name: 'Status VPN',
      value: vpnStatus?.data?.status === 'operational' ? 'Operacyjny' : 'Błąd',
      icon: Shield,
      color: vpnStatus?.data?.status === 'operational' ? 'text-green-600' : 'text-red-600',
      bgColor: vpnStatus?.data?.status === 'operational' ? 'bg-green-100' : 'bg-red-100',
    },
    {
      name: 'Aktywne połączenia',
      value: vpnStatus?.data?.active_connections || 0,
      icon: Activity,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100',
    },
    {
      name: 'Użytkownicy VPN',
      value: vpnStatus?.data?.total_users || 0,
      icon: Users,
      color: 'text-purple-600',
      bgColor: 'bg-purple-100',
    },
    {
      name: 'TeamSpeak',
      value: 'Online',
      icon: Headphones,
      color: 'text-green-600',
      bgColor: 'bg-green-100',
    },
  ]

  const recentActivity = [
    {
      id: 1,
      type: 'vpn_connection',
      message: 'Nowe połączenie VPN',
      timestamp: '2 minuty temu',
      status: 'success',
    },
    {
      id: 2,
      type: 'user_registration',
      message: 'Nowa rejestracja użytkownika',
      timestamp: '15 minut temu',
      status: 'pending',
    },
    {
      id: 3,
      type: 'teamspeak_user',
      message: 'Utworzono konto TeamSpeak',
      timestamp: '1 godzinę temu',
      status: 'success',
    },
  ]

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'success':
        return <CheckCircle className="h-5 w-5 text-green-600" />
      case 'pending':
        return <Clock className="h-5 w-5 text-yellow-600" />
      case 'error':
        return <AlertCircle className="h-5 w-5 text-red-600" />
      default:
        return <Activity className="h-5 w-5 text-blue-600" />
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
        <p className="text-muted-foreground">
          Witaj, {user?.username}! Oto przegląd Twojego systemu Safe-Spac.
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <div key={stat.name} className="card">
            <div className="card-content">
              <div className="flex items-center">
                <div className={`flex-shrink-0 p-3 rounded-lg ${stat.bgColor}`}>
                  <stat.icon className={`h-6 w-6 ${stat.color}`} />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-muted-foreground">{stat.name}</p>
                  <p className="text-2xl font-semibold text-foreground">{stat.value}</p>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* VPN Status */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Status VPN</h3>
            <p className="card-description">
              Aktualny stan połączeń WireGuard
            </p>
          </div>
          <div className="card-content">
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Status systemu</span>
                <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                  vpnStatus?.data?.status === 'operational' 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-red-100 text-red-800'
                }`}>
                  {vpnStatus?.data?.status === 'operational' ? 'Operacyjny' : 'Błąd'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Aktywne połączenia</span>
                <span className="text-sm font-medium">{vpnStatus?.data?.active_connections || 0}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Łączna liczba użytkowników</span>
                <span className="text-sm font-medium">{vpnStatus?.data?.total_users || 0}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Ostatnia aktualizacja</span>
                <span className="text-sm text-muted-foreground">
                  {vpnStatus?.data?.timestamp ? new Date(vpnStatus.data.timestamp).toLocaleTimeString() : 'N/A'}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Ostatnia aktywność</h3>
            <p className="card-description">
              Najnowsze wydarzenia w systemie
            </p>
          </div>
          <div className="card-content">
            <div className="space-y-4">
              {recentActivity.map((activity) => (
                <div key={activity.id} className="flex items-start space-x-3">
                  {getStatusIcon(activity.status)}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-foreground">{activity.message}</p>
                    <p className="text-sm text-muted-foreground">{activity.timestamp}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Szybkie akcje</h3>
          <p className="card-description">
            Często używane funkcje
          </p>
        </div>
        <div className="card-content">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <button className="btn-outline flex items-center justify-center space-x-2 p-4">
              <Shield className="h-5 w-5" />
              <span>Konfiguracja VPN</span>
            </button>
            <button className="btn-outline flex items-center justify-center space-x-2 p-4">
              <Headphones className="h-5 w-5" />
              <span>TeamSpeak</span>
            </button>
            <button className="btn-outline flex items-center justify-center space-x-2 p-4">
              <Users className="h-5 w-5" />
              <span>Użytkownicy</span>
            </button>
            <button className="btn-outline flex items-center justify-center space-x-2 p-4">
              <TrendingUp className="h-5 w-5" />
              <span>Statystyki</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}