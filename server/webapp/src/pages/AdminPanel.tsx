import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Shield, Users, Settings } from 'lucide-react'

const AdminPanel: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Panel Administracyjny</h1>
        <p className="text-muted-foreground mt-2">
          Zarządzanie systemem Safe-Spac
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-blue-100">
                <Users className="h-5 w-5 text-blue-600" />
              </div>
              <CardTitle className="text-lg">Zarządzanie użytkownikami</CardTitle>
            </div>
            <CardDescription>
              Zatwierdzaj rejestracje i zarządzaj kontami
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="outline" className="w-full">
              Przejdź
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-green-100">
                <Shield className="h-5 w-5 text-green-600" />
              </div>
              <CardTitle className="text-lg">Konfiguracja VPN</CardTitle>
            </div>
            <CardDescription>
              Zarządzaj ustawieniami WireGuard
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="outline" className="w-full">
              Przejdź
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div className="flex items-center space-x-3">
              <div className="p-2 rounded-lg bg-purple-100">
                <Settings className="h-5 w-5 text-purple-600" />
              </div>
              <CardTitle className="text-lg">Ustawienia systemu</CardTitle>
            </div>
            <CardDescription>
              Konfiguracja Authelia i innych usług
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="outline" className="w-full">
              Przejdź
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Status systemu</CardTitle>
          <CardDescription>
            Przegląd działania wszystkich usług
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="h-3 w-3 rounded-full bg-green-500"></div>
                <span className="font-medium">Core API</span>
              </div>
              <span className="text-sm text-green-600">Operacyjny</span>
            </div>
            
            <div className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="h-3 w-3 rounded-full bg-green-500"></div>
                <span className="font-medium">Authelia</span>
              </div>
              <span className="text-sm text-green-600">Operacyjny</span>
            </div>
            
            <div className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="h-3 w-3 rounded-full bg-green-500"></div>
                <span className="font-medium">WireGuard</span>
              </div>
              <span className="text-sm text-green-600">Operacyjny</span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default AdminPanel
