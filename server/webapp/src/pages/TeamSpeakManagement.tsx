import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Headphones, Users, MessageSquare, Settings, UserPlus } from 'lucide-react'

const TeamSpeakManagement: React.FC = () => {
  // Przykładowe dane TeamSpeak
  const channels = [
    {
      id: '1',
      name: 'Główny',
      description: 'Główny kanał serwera',
      users: 5,
      maxUsers: 10
    },
    {
      id: '2',
      name: 'Gaming',
      description: 'Kanał dla graczy',
      users: 3,
      maxUsers: 8
    },
    {
      id: '3',
      name: 'Czat',
      description: 'Ogólny kanał czatu',
      users: 2,
      maxUsers: 15
    }
  ]

  const users = [
    {
      id: '1',
      username: 'admin',
      nickname: 'Administrator',
      group: 'Server Admin',
      lastSeen: '2 min temu',
      online: true
    },
    {
      id: '2',
      username: 'user1',
      nickname: 'Gracz1',
      group: 'User',
      lastSeen: '5 min temu',
      online: true
    },
    {
      id: '3',
      username: 'user2',
      nickname: 'Gracz2',
      group: 'User',
      lastSeen: '1 godz temu',
      online: false
    }
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Zarządzanie TeamSpeak</h1>
        <p className="text-muted-foreground mt-2">
          Zarządzaj kanałami i użytkownikami serwera TeamSpeak
        </p>
      </div>

      {/* Status serwera */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Status serwera</CardTitle>
              <CardDescription>
                Informacje o działaniu serwera TeamSpeak
              </CardDescription>
            </div>
            <div className="flex items-center space-x-2">
              <div className="h-3 w-3 rounded-full bg-green-500"></div>
              <span className="text-sm font-medium text-green-600">Online</span>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="p-4 bg-blue-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Users className="h-5 w-5 text-blue-600" />
                <span className="text-sm font-medium text-blue-800">Użytkownicy online</span>
              </div>
              <p className="text-2xl font-bold text-blue-900 mt-1">8</p>
            </div>
            
            <div className="p-4 bg-green-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <MessageSquare className="h-5 w-5 text-green-600" />
                <span className="text-sm font-medium text-green-800">Kanały</span>
              </div>
              <p className="text-2xl font-bold text-green-900 mt-1">{channels.length}</p>
            </div>
            
            <div className="p-4 bg-purple-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Headphones className="h-5 w-5 text-purple-600" />
                <span className="text-sm font-medium text-purple-800">Port</span>
              </div>
              <p className="text-2xl font-bold text-purple-900 mt-1">9987</p>
            </div>
            
            <div className="p-4 bg-orange-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Settings className="h-5 w-5 text-orange-600" />
                <span className="text-sm font-medium text-orange-800">Wersja</span>
              </div>
              <p className="text-2xl font-bold text-orange-900 mt-1">3.6.1</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Kanały */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Kanały</CardTitle>
              <CardDescription>
                Zarządzaj kanałami serwera
              </CardDescription>
            </div>
            <Button>
              <MessageSquare className="h-4 w-4 mr-2" />
              Utwórz kanał
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {channels.map((channel) => (
              <div key={channel.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">{channel.name}</p>
                  <p className="text-sm text-muted-foreground">{channel.description}</p>
                  <p className="text-xs text-muted-foreground">
                    Użytkownicy: {channel.users}/{channel.maxUsers}
                  </p>
                </div>
                <div className="flex space-x-2">
                  <Button size="sm" variant="outline">
                    Edytuj
                  </Button>
                  <Button size="sm" variant="outline">
                    Usuń
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Użytkownicy */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Użytkownicy</CardTitle>
              <CardDescription>
                Zarządzaj użytkownikami TeamSpeak
              </CardDescription>
            </div>
            <Button>
              <UserPlus className="h-4 w-4 mr-2" />
              Dodaj użytkownika
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {users.map((user) => (
              <div key={user.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center space-x-3">
                  <div className={`h-10 w-10 rounded-full flex items-center justify-center ${
                    user.online ? 'bg-green-100' : 'bg-gray-100'
                  }`}>
                    <Users className={`h-5 w-5 ${
                      user.online ? 'text-green-600' : 'text-gray-600'
                    }`} />
                  </div>
                  <div>
                    <p className="font-medium">{user.nickname}</p>
                    <p className="text-sm text-muted-foreground">@{user.username}</p>
                    <div className="flex items-center space-x-2 mt-1">
                      <span className={`px-2 py-1 rounded-full text-xs ${
                        user.group === 'Server Admin' 
                          ? 'bg-purple-100 text-purple-800' 
                          : 'bg-blue-100 text-blue-800'
                      }`}>
                        {user.group}
                      </span>
                      <span className={`px-2 py-1 rounded-full text-xs ${
                        user.online 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-gray-100 text-gray-800'
                      }`}>
                        {user.online ? 'Online' : 'Offline'}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="flex space-x-2">
                  <Button size="sm" variant="outline">
                    Edytuj
                  </Button>
                  <Button size="sm" variant="outline">
                    Usuń
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Ustawienia */}
      <Card>
        <CardHeader>
          <CardTitle>Ustawienia serwera</CardTitle>
          <CardDescription>
            Konfiguracja parametrów serwera
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Maksymalna liczba użytkowników
              </label>
              <div className="p-3 bg-gray-50 rounded-md">
                32
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Port główny
              </label>
              <div className="p-3 bg-gray-50 rounded-md">
                9987
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Port Query
              </label>
              <div className="p-3 bg-gray-50 rounded-md">
                10011
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <div className="p-3 bg-gray-50 rounded-md">
                <span className="px-2 py-1 rounded-full text-xs bg-green-100 text-green-800">
                  Aktywny
                </span>
              </div>
            </div>
          </div>
          
          <div className="mt-4 flex space-x-2">
            <Button variant="outline">
              <Settings className="h-4 w-4 mr-2" />
              Edytuj ustawienia
            </Button>
            <Button variant="outline">
              Restart serwera
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default TeamSpeakManagement
