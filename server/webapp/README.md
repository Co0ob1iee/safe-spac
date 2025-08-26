# Safe-Spac WebApp

Nowoczesny frontend dla platformy Safe-Spac, napisany w React z TypeScript.

## 🚀 Funkcjonalności

### Użytkownik
- Dashboard z przeglądem systemu
- Zarządzanie konfiguracją VPN
- Dostęp do TeamSpeak
- Profil użytkownika

### Administrator
- Panel zarządzania użytkownikami
- Zatwierdzanie rejestracji
- Zarządzanie zaproszeniami
- Monitoring systemu
- Zarządzanie TeamSpeak

## 🛠️ Technologie

- **React 18** - Framework UI
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Tailwind CSS** - Styling
- **React Router** - Routing
- **React Query** - State management
- **React Hook Form** - Form handling
- **Zod** - Validation
- **Lucide React** - Icons

## 📋 Wymagania

- Node.js 18+
- npm lub yarn

## 🚀 Instalacja i uruchomienie

### Instalacja zależności
```bash
npm install
# lub
yarn install
```

### Uruchomienie w trybie deweloperskim
```bash
npm run dev
# lub
yarn dev
```

Aplikacja będzie dostępna pod adresem `http://localhost:3000`

### Budowanie produkcyjne
```bash
npm run build
# lub
yarn build
```

### Podgląd produkcyjnej wersji
```bash
npm run preview
# lub
yarn preview
```

## 🔧 Konfiguracja

Skopiuj plik `.env.example` do `.env` i dostosuj zmienne:

```bash
cp .env.example .env
```

### Zmienne środowiskowe

- `VITE_API_URL` - URL do Core API
- `VITE_APP_NAME` - Nazwa aplikacji
- `VITE_APP_VERSION` - Wersja aplikacji
- `VITE_ENABLE_TEAMSPEAK` - Włącz/wyłącz TeamSpeak
- `VITE_ENABLE_VPN_MANAGEMENT` - Włącz/wyłącz zarządzanie VPN
- `VITE_ENABLE_USER_REGISTRATION` - Włącz/wyłącz rejestrację użytkowników

## 📁 Struktura projektu

```
src/
├── components/          # Komponenty UI
├── contexts/           # React Contexts
├── lib/               # Biblioteki i utilities
├── pages/             # Strony aplikacji
├── types/             # TypeScript types
├── App.tsx            # Główny komponent
├── main.tsx           # Entry point
└── index.css          # Główny CSS
```

## 🎨 Design System

Aplikacja używa Tailwind CSS z custom design system:

- **Kolory**: Primary, secondary, accent, destructive
- **Typografia**: Inter font family
- **Spacing**: Consistent spacing scale
- **Components**: Predefiniowane komponenty (buttons, inputs, cards)

## 🔒 Bezpieczeństwo

- Protected routes z autoryzacją
- JWT token management
- Role-based access control
- Form validation z Zod
- CSRF protection

## 📱 Responsywność

- Mobile-first design
- Responsive sidebar
- Touch-friendly interface
- Adaptive layouts

## 🧪 Testy

```bash
# Uruchom testy
npm test

# Testy z coverage
npm run test:coverage

# Type checking
npm run type-check
```

## 📊 Performance

- Code splitting z Vite
- Lazy loading komponentów
- Optimized bundle size
- React Query caching

## 🔄 Integracja

### Core API
- RESTful API integration
- Real-time updates
- Error handling
- Loading states

### TeamSpeak 6
- Server Query integration
- User management
- Channel management
- Real-time status

### WireGuard
- VPN configuration
- Key management
- Connection monitoring
- User provisioning

## 🚀 Deployment

### Docker
```bash
docker build -t safe-spac-webapp .
docker run -p 80:80 safe-spac-webapp
```

### Nginx
```bash
# Skopiuj pliki do /var/www/html
# Skonfiguruj nginx
nginx -s reload
```

## 📝 Licencja

MIT License

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📞 Support

- Issues: GitHub Issues
- Documentation: README files
- Wiki: Project Wiki