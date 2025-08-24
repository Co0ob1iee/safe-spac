// docs/webapp_deployment_plan.md
# Plan wdrożenia portalu webapp

## 1. Cele i zakres
Portal ma zapewniać:
- logowanie i rejestrację z systemem akceptacji nowych kont,
- role użytkowników (np. użytkownik, moderator, administrator),
- stronę główną z newsami i komentarzami,
- forum dyskusyjne,
- panel użytkownika, panel moderacji i panel administracyjny,
- sekcję „Download” z materiałami do pobrania,
- widoczność dla niezalogowanych ograniczoną do strony logowania/rejestracji.

## 2. Architektura systemu
### 2.1 Frontend
- **Stack:** TypeScript + React (Vite, shadcn/ui, ESLint, Prettier).
- **Strony:** 
  - `News` (lista + komentarze),
  - `Forum` (lista działów, wątki, posty),
  - `Panel Użytkownika`,
  - `Panel Moderacji`,
  - `Panel Administracji`,
  - `Download`,
  - `Auth` (logowanie, rejestracja, reset hasła).
- **Routing:** react-router, ochrona tras wg roli.
- **Stan:** React Query dla danych z API.

### 2.2 Backend
- **Stack:** ASP.NET Core (.NET 8) + EF Core + PostgreSQL.
- **Warstwy:** API (Minimal API), logika domenowa, warstwa danych.
- **Bezpieczeństwo:** JWT + Refresh Token, hasła z Argon2.
- **Role:** USER, MODERATOR, ADMIN – mapowane na uprawnienia.
- **Funkcje:** 
  - zarządzanie newsami i komentarzami,
  - obsługa forum (działy, wątki, posty),
  - zarządzanie plikami w sekcji „Download”,
  - akceptacja rejestracji (workflow: rejestracja → oczekujące → akceptacja/odrzucenie).

### 2.3 Baza danych
- **Użytkownicy:** dane profilu, status (aktywny/oczekujący/zablokowany), role.
- **News:** tytuł, treść, autor, daty, komentarze.
- **Komentarze:** treść, autor, powiązanie z newsem.
- **Forum:** działy, wątki, posty, uprawnienia moderacyjne.
- **Pliki:** metadane plików do pobrania.

## 3. Moduły funkcjonalne
1. **Autoryzacja i rejestracja**
   - Rejestracja zapisuje użytkownika jako „oczekujący”.
   - Administrator/moderator akceptuje lub odrzuca.
   - Logowanie dostępne tylko dla zaakceptowanych kont.

2. **News + komentarze**
   - Newsy widoczne po zalogowaniu.
   - Komentarze z paginacją, możliwość moderacji (ukrycie, usunięcie).

3. **Forum**
   - Działy i wątki tworzone przez uprawnione role.
   - Moderacja postów (edycja, usuwanie, blokowanie wątku).

4. **Panele**
   - **Użytkownika:** profil, zmiana hasła, aktywność.
   - **Moderacji:** kolejka zgłoszeń, zarządzanie komentarzami/postami.
   - **Administracji:** zarządzanie użytkownikami, rolami, newsami, działami forum, plikami „Download”.

5. **Sekcja Download**
   - Lista plików z opisem i uprawnieniami.
   - Licznik pobrań, ewentualna integracja z CDN.

## 4. Proces wdrożenia
1. **Przygotowanie środowiska**
   - Repozytorium z podziałem na `frontend/` i `backend/`.
   - Konfiguracja CI/CD (np. GitHub Actions).
2. **Implementacja backendu**
   - Szablon projektu ASP.NET Core.
   - Modele danych, migracje, testy jednostkowe.
3. **Implementacja frontendu**
   - Vite + React + shadcn/ui.
   - Strony zgodnie z listą w sekcji 2.1.
4. **Integracja i testy**
   - Testy jednostkowe (xUnit) i e2e (Playwright).
   - Walidacja ról i uprawnień.
5. **Deploy**
   - Docker (frontend i backend w osobnych obrazach).
   - Reverse proxy (np. Nginx) + Authelia dla SSO jeśli wymagane.
6. **Monitoring i utrzymanie**
   - Logowanie (Serilog), metryki (Prometheus).
   - Backup bazy danych, rotacja logów.

## 5. Harmonogram wysokopoziomowy
1. **Tydzień 1–2:** konfiguracja repo + szkielety projektów, baza danych.
2. **Tydzień 3–4:** autoryzacja, rejestracja z akceptacją.
3. **Tydzień 5–6:** newsy, komentarze, sekcja „Download”.
4. **Tydzień 7–8:** forum + panele użytkownika, moderacji, administracji.
5. **Tydzień 9:** testy e2e, optymalizacja, dokumentacja.
6. **Tydzień 10:** deploy na środowisko produkcyjne.

## 6. Bezpieczeństwo i zgodność
- Wymuszanie HTTPS, HSTS.
- WAF przy proxy (np. Nginx + ModSecurity).
- Regularne aktualizacje zależności.
- Zgodność z RODO (przechowywanie i usuwanie danych użytkownika).

