# Safe-Spac Core API

Backend API dla platformy Safe-Spac, napisany w Go z użyciem frameworka Fiber.

## 🚀 Funkcjonalności

### Authentication & Authorization
- Rejestracja użytkowników z systemem zaproszeń
- Logowanie z JWT tokenami
- System captcha dla bezpieczeństwa
- Role użytkowników (admin, user)

### User Management
- CRUD operacje na użytkownikach
- Zarządzanie statusem konta
- System zatwierdzania rejestracji przez adminów

### VPN Management
- Integracja z WireGuard provisioner
- Konfiguracja kluczy VPN
- Włączanie/wyłączanie VPN dla użytkowników
- Monitoring statusu VPN

### TeamSpeak Integration
- Zarządzanie użytkownikami TS6
- Tworzenie i zarządzanie kanałami
- Integracja z TeamSpeak Server Query

## 📋 API Endpoints

### Authentication
```
POST /api/auth/register          - Rejestracja użytkownika
POST /api/auth/login             - Logowanie
POST /api/auth/logout            - Wylogowanie
POST /api/auth/captcha/challenge - Generowanie captcha
POST /api/auth/captcha/verify    - Weryfikacja captcha
```

### User Management
```
GET    /api/users                - Lista użytkowników
GET    /api/users/:id            - Pobierz użytkownika
PUT    /api/users/:id            - Aktualizuj użytkownika
DELETE /api/users/:id            - Usuń użytkownika
POST   /api/users/:id/vpn/enable - Włącz VPN
POST   /api/users/:id/vpn/disable- Wyłącz VPN
```

### Admin Panel
```
GET    /api/admin/registrations           - Lista oczekujących rejestracji
POST   /api/admin/registrations/:id/approve - Zatwierdź rejestrację
POST   /api/admin/registrations/:id/reject  - Odrzuć rejestrację
POST   /api/admin/invites                  - Utwórz zaproszenie
GET    /api/admin/invites                  - Lista zaproszeń
DELETE /api/admin/invites/:token           - Usuń zaproszenie
POST   /api/admin/authelia/restart        - Restart Authelia
```

### VPN Management
```
GET  /api/vpn/config/:user_id - Pobierz konfigurację VPN
POST /api/vpn/config/:user_id - Aktualizuj konfigurację VPN
GET  /api/vpn/status          - Status VPN
```

### TeamSpeak Management
```
GET    /api/teamspeak/users           - Lista użytkowników TS
POST   /api/teamspeak/users           - Utwórz użytkownika TS
PUT    /api/teamspeak/users/:id       - Aktualizuj użytkownika TS
DELETE /api/teamspeak/users/:id       - Usuń użytkownika TS
GET    /api/teamspeak/channels        - Lista kanałów
POST   /api/teamspeak/channels        - Utwórz kanał
```

## 🛠️ Instalacja i uruchomienie

### Wymagania
- Go 1.24+
- Docker (opcjonalnie)

### Lokalne uruchomienie
```bash
# Pobierz zależności
go mod tidy

# Uruchom aplikację
go run cmd/coreapi/main.go
```

### Docker
```bash
# Zbuduj obraz
docker build -t safe-spac-core-api .

# Uruchom kontener
docker run -p 8080:8080 \
  -v /path/to/data:/data \
  -e DATA_DIR=/data \
  safe-spac-core-api
```

### Zmienne środowiskowe
```bash
DATA_DIR=/data                           # Katalog danych
PORT=8080                                # Port serwera
JWT_SECRET=your-secret-key              # Sekret JWT
WG_PROVISIONER_URL=http://wg:8081       # URL WireGuard provisioner
AUTHELIA_USERS=/authelia/users.yml      # Ścieżka do pliku użytkowników Authelia
```

## 📁 Struktura danych

Aplikacja przechowuje dane w plikach JSON w katalogu `/data`:

- `users.json` - Użytkownicy systemu
- `pending.json` - Oczekujące rejestracje
- `invites.json` - Zaproszenia
- `teamspeak_users.json` - Użytkownicy TeamSpeak
- `captcha_store.json` - Store captcha

## 🔒 Bezpieczeństwo

- Hasła hashowane z użyciem Argon2
- JWT tokeny dla autoryzacji
- System captcha dla rejestracji
- Walidacja danych wejściowych
- Rate limiting (planowane)

## 🧪 Testy

```bash
# Uruchom testy
go test ./...

# Testy z coverage
go test -cover ./...
```

## 📊 Monitoring

- Endpoint `/health` dla health check
- Strukturalne logowanie
- Metryki (planowane)

## 🔄 Integracja

### WireGuard
Integracja z WireGuard provisioner przez HTTP API.

### TeamSpeak 6
Zarządzanie przez Server Query API.

### Authelia
Integracja z systemem autoryzacji Authelia.

## 📝 Licencja

MIT License
