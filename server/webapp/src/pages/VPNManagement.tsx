import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Download, Upload, Key, Activity } from 'lucide-react'

const VPNManagement: React.FC = () => {
  // Przykładowe dane VPN
  const vpnConfig = {
    enabled: true,
    ipAddress: '10.66.0.2',
    publicKey: 'abc123def456ghi789...',
    privateKey: 'xyz789uvw456rst123...',
    endpoint: 'vpn.example.com:51820',
    dns: '10.66.0.1'
  }

  const vpnStats = {
    bytesReceived: '1.2 GB',
    bytesSent: '856 MB',
    lastHandshake: '2 min temu',
    status: 'connected'
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Zarządzanie VPN</h1>
        <p className="text-muted-foreground mt-2">
          Konfiguracja i monitoring połączenia WireGuard
        </p>
      </div>

      {/* Status VPN */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Status połączenia</CardTitle>
              <CardDescription>
                Aktualny stan połączenia VPN
              </CardDescription>
            </div>
            <div className="flex items-center space-x-2">
              <div className={`h-3 w-3 rounded-full ${
                vpnStats.status === 'connected' ? 'bg-green-500' : 'bg-red-500'
              }`}></div>
              <span className={`text-sm font-medium ${
                vpnStats.status === 'connected' ? 'text-green-600' : 'text-red-600'
              }`}>
                {vpnStats.status === 'connected' ? 'Połączony' : 'Rozłączony'}
              </span>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 bg-blue-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Download className="h-5 w-5 text-blue-600" />
                <span className="text-sm font-medium text-blue-800">Odebrane</span>
              </div>
              <p className="text-2xl font-bold text-blue-900 mt-1">{vpnStats.bytesReceived}</p>
            </div>
            
            <div className="p-4 bg-green-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Upload className="h-5 w-5 text-green-600" />
                <span className="text-sm font-medium text-green-800">Wysłane</span>
              </div>
              <p className="text-2xl font-bold text-green-900 mt-1">{vpnStats.bytesSent}</p>
            </div>
            
            <div className="p-4 bg-purple-50 rounded-lg">
              <div className="flex items-center space-x-2">
                <Activity className="h-5 w-5 text-purple-600" />
                <span className="text-sm font-medium text-purple-800">Ostatni handshake</span>
              </div>
              <p className="text-2xl font-bold text-purple-900 mt-1">{vpnStats.lastHandshake}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Konfiguracja VPN */}
      <Card>
        <CardHeader>
          <CardTitle>Konfiguracja WireGuard</CardTitle>
          <CardDescription>
            Szczegóły konfiguracji VPN
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adres IP
                </label>
                <div className="p-3 bg-gray-50 rounded-md font-mono text-sm">
                  {vpnConfig.ipAddress}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Endpoint
                </label>
                <div className="p-3 bg-gray-50 rounded-md font-mono text-sm">
                  {vpnConfig.endpoint}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  DNS
                </label>
                <div className="p-3 bg-gray-50 rounded-md font-mono text-sm">
                  {vpnConfig.dns}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Status
                </label>
                <div className="p-3 bg-gray-50 rounded-md">
                  <span className={`px-2 py-1 rounded-full text-xs ${
                    vpnConfig.enabled 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {vpnConfig.enabled ? 'Aktywny' : 'Nieaktywny'}
                  </span>
                </div>
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Klucz publiczny
              </label>
              <div className="p-3 bg-gray-50 rounded-md font-mono text-xs break-all">
                {vpnConfig.publicKey}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Akcje */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Pobierz konfigurację</CardTitle>
            <CardDescription>
              Pobierz plik konfiguracyjny WireGuard
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button className="w-full">
              <Download className="h-4 w-4 mr-2" />
              Pobierz .conf
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Zarządzanie kluczami</CardTitle>
            <CardDescription>
              Wygeneruj nowe klucze lub zaktualizuj istniejące
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <Button variant="outline" className="w-full">
                <Key className="h-4 w-4 mr-2" />
                Wygeneruj nowe klucze
              </Button>
              <Button variant="outline" className="w-full">
                <Upload className="h-4 w-4 mr-2" />
                Zaktualizuj konfigurację
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Instrukcje */}
      <Card>
        <CardHeader>
          <CardTitle>Instrukcje połączenia</CardTitle>
          <CardDescription>
            Jak połączyć się z VPN
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3 text-sm">
            <div className="flex items-start space-x-3">
              <div className="h-6 w-6 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-bold text-blue-600">1</span>
              </div>
              <p>Pobierz plik konfiguracyjny WireGuard (.conf)</p>
            </div>
            
            <div className="flex items-start space-x-3">
              <div className="h-6 w-6 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-bold text-blue-600">2</span>
              </div>
              <p>Zainstaluj aplikację WireGuard na swoim urządzeniu</p>
            </div>
            
            <div className="flex items-start space-x-3">
              <div className="h-6 w-6 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-bold text-blue-600">3</span>
              </div>
              <p>Zaimportuj plik konfiguracyjny do aplikacji</p>
            </div>
            
            <div className="flex items-start space-x-3">
              <div className="h-6 w-6 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-bold text-blue-600">4</span>
              </div>
              <p>Kliknij "Połącz" w aplikacji WireGuard</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default VPNManagement
