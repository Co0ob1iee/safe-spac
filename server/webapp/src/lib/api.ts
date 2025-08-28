import axios from 'axios'

// Konfiguracja bazowego URL API
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080'

// Tworzenie instancji axios z domyślną konfiguracją
export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Interceptor do dodawania tokenu autoryzacji
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Interceptor do obsługi błędów
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token wygasł lub jest nieprawidłowy
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// Typy dla API
export interface LoginRequest {
  email: string
  password: string
}

export interface LoginResponse {
  ok: boolean
  token: string
  user: User
}

export interface RegisterRequest {
  email: string
  username: string
  password: string
  inviteToken?: string
}

export interface User {
  id: string
  email: string
  username: string
  role: 'admin' | 'user'
  status: 'active' | 'suspended' | 'pending'
  created_at: string
  updated_at: string
  vpn_config?: VPNConfig
}

export interface VPNConfig {
  public_key: string
  private_key: string
  ip_address: string
  enabled: boolean
}

export interface Registration {
  id: string
  email: string
  username: string
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
  invite_token?: string
}

export interface Invite {
  token: string
  email: string
  created_at: string
  expires_at: string
  used: boolean
}

// Funkcje API
export const authAPI = {
  login: (data: LoginRequest) => 
    api.post<LoginResponse>('/api/auth/login', data),
  
  register: (data: RegisterRequest) => 
    api.post('/api/auth/register', data),
  
  logout: () => 
    api.post('/api/auth/logout'),
  
  getCaptchaChallenge: () => 
    api.post('/api/auth/captcha/challenge'),
  
  verifyCaptcha: (id: string, answer: string) => 
    api.post('/api/auth/captcha/verify', { id, answer }),
}

export const usersAPI = {
  getUsers: () => 
    api.get<User[]>('/api/users'),
  
  getUser: (id: string) => 
    api.get<User>(`/api/users/${id}`),
  
  updateUser: (id: string, data: Partial<User>) => 
    api.put<User>(`/api/users/${id}`, data),
  
  deleteUser: (id: string) => 
    api.delete(`/api/users/${id}`),
  
  enableVPN: (id: string) => 
    api.post(`/api/users/${id}/vpn/enable`),
  
  disableVPN: (id: string) => 
    api.post(`/api/users/${id}/vpn/disable`),
}

export const adminAPI = {
  getRegistrations: () => 
    api.get<Registration[]>('/api/admin/registrations'),
  
  approveRegistration: (id: string) => 
    api.post(`/api/admin/registrations/${id}/approve`),
  
  rejectRegistration: (id: string) => 
    api.post(`/api/admin/registrations/${id}/reject`),
  
  createInvite: (email: string) => 
    api.post('/api/admin/invites', { email }),
  
  getInvites: () => 
    api.get<Invite[]>('/api/admin/invites'),
  
  deleteInvite: (token: string) => 
    api.delete(`/api/admin/invites/${token}`),
  
  restartAuthelia: () => 
    api.post('/api/admin/authelia/restart'),
}

export const vpnAPI = {
  getConfig: (userId: string) => 
    api.get(`/api/vpn/config/${userId}`),
  
  updateConfig: (userId: string, data: Partial<VPNConfig>) => 
    api.post(`/api/vpn/config/${userId}`, data),
  
  getStatus: () => 
    api.get('/api/vpn/status'),
}

export const teamspeakAPI = {
  getUsers: () => 
    api.get('/api/teamspeak/users'),
  
  createUser: (data: any) => 
    api.post('/api/teamspeak/users', data),
  
  updateUser: (id: string, data: any) => 
    api.put(`/api/teamspeak/users/${id}`, data),
  
  deleteUser: (id: string) => 
    api.delete(`/api/teamspeak/users/${id}`),
  
  getChannels: () => 
    api.get('/api/teamspeak/channels'),
  
  createChannel: (data: any) => 
    api.post('/api/teamspeak/channels', data),
}
