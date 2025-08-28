import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Users, UserPlus, Shield, CheckCircle, XCircle } from 'lucide-react'

const UserManagement: React.FC = () => {
  // Przykładowe dane użytkowników
  const users = [
    {
      id: '1',
      username: 'admin',
      email: 'admin@example.com',
      role: 'admin',
      status: 'active',
      vpnEnabled: true
    },
    {
      id: '2',
      username: 'user1',
      email: 'user1@example.com',
      role: 'user',
      status: 'active',
      vpnEnabled: true
    },
    {
      id: '3',
      username: 'user2',
      email: 'user2@example.com',
      role: 'user',
      status: 'pending',
      vpnEnabled: false
    }
  ]

  const pendingRegistrations = [
    {
      id: '4',
      username: 'newuser',
      email: 'newuser@example.com',
      createdAt: '2024-01-15'
    }
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Zarządzanie użytkownikami</h1>
        <p className="text-muted-foreground mt-2">
          Zarządzaj kontami użytkowników i zatwierdzaj rejestracje
        </p>
      </div>

      {/* Oczekujące rejestracje */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Oczekujące rejestracje</CardTitle>
              <CardDescription>
                Zatwierdź lub odrzuć nowe konta
              </CardDescription>
            </div>
            <Button>
              <UserPlus className="h-4 w-4 mr-2" />
              Utwórz zaproszenie
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {pendingRegistrations.map((registration) => (
              <div key={registration.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">{registration.username}</p>
                  <p className="text-sm text-muted-foreground">{registration.email}</p>
                  <p className="text-xs text-muted-foreground">
                    Zarejestrowano: {registration.createdAt}
                  </p>
                </div>
                <div className="flex space-x-2">
                  <Button size="sm" variant="outline">
                    <CheckCircle className="h-4 w-4 mr-1" />
                    Zatwierdź
                  </Button>
                  <Button size="sm" variant="outline">
                    <XCircle className="h-4 w-4 mr-1" />
                    Odrzuć
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Lista użytkowników */}
      <Card>
        <CardHeader>
          <CardTitle>Użytkownicy systemu</CardTitle>
          <CardDescription>
            Zarządzaj istniejącymi kontami
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {users.map((user) => (
              <div key={user.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center space-x-3">
                  <div className="h-10 w-10 rounded-full bg-gray-100 flex items-center justify-center">
                    <Users className="h-5 w-5 text-gray-600" />
                  </div>
                  <div>
                    <p className="font-medium">{user.username}</p>
                    <p className="text-sm text-muted-foreground">{user.email}</p>
                    <div className="flex items-center space-x-2 mt-1">
                      <span className={`px-2 py-1 rounded-full text-xs ${
                        user.role === 'admin' 
                          ? 'bg-purple-100 text-purple-800' 
                          : 'bg-blue-100 text-blue-800'
                      }`}>
                        {user.role}
                      </span>
                      <span className={`px-2 py-1 rounded-full text-xs ${
                        user.status === 'active' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {user.status}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <Button 
                    size="sm" 
                    variant={user.vpnEnabled ? "outline" : "default"}
                  >
                    <Shield className="h-4 w-4 mr-1" />
                    {user.vpnEnabled ? 'VPN ON' : 'VPN OFF'}
                  </Button>
                  <Button size="sm" variant="outline">
                    Edytuj
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default UserManagement
