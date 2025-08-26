import axios from 'axios'

// Create axios instance
export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor to add auth token
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

// Response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// API endpoints
export const endpoints = {
  // Auth
  auth: {
    login: '/auth/login',
    register: '/auth/register',
    logout: '/auth/logout',
    captcha: {
      challenge: '/auth/captcha/challenge',
      verify: '/auth/captcha/verify',
    },
  },
  
  // Users
  users: {
    list: '/users',
    get: (id: string) => `/users/${id}`,
    update: (id: string) => `/users/${id}`,
    delete: (id: string) => `/users/${id}`,
    vpn: {
      enable: (id: string) => `/users/${id}/vpn/enable`,
      disable: (id: string) => `/users/${id}/vpn/disable`,
    },
  },
  
  // Admin
  admin: {
    registrations: {
      list: '/admin/registrations',
      approve: (id: string) => `/admin/registrations/${id}/approve`,
      reject: (id: string) => `/admin/registrations/${id}/reject`,
    },
    invites: {
      list: '/admin/invites',
      create: '/admin/invites',
      delete: (token: string) => `/admin/invites/${token}`,
    },
    authelia: {
      restart: '/admin/authelia/restart',
    },
  },
  
  // VPN
  vpn: {
    config: (userId: string) => `/vpn/config/${userId}`,
    status: '/vpn/status',
  },
  
  // TeamSpeak
  teamspeak: {
    users: {
      list: '/teamspeak/users',
      create: '/teamspeak/users',
      update: (id: string) => `/teamspeak/users/${id}`,
      delete: (id: string) => `/teamspeak/users/${id}`,
    },
    channels: {
      list: '/teamspeak/channels',
      create: '/teamspeak/channels',
    },
  },
  
  // Health
  health: '/health',
}

// Helper functions
export const apiClient = {
  // Auth
  login: (credentials: { email: string; password: string }) =>
    api.post(endpoints.auth.login, credentials),
  
  register: (data: { email: string; username: string; password: string; inviteToken?: string }) =>
    api.post(endpoints.auth.register, data),
  
  // Users
  getUsers: () => api.get(endpoints.users.list),
  getUser: (id: string) => api.get(endpoints.users.get(id)),
  updateUser: (id: string, data: any) => api.put(endpoints.users.update(id), data),
  deleteUser: (id: string) => api.delete(endpoints.users.delete(id)),
  
  // VPN
  enableVPN: (userId: string) => api.post(endpoints.users.vpn.enable(userId)),
  disableVPN: (userId: string) => api.post(endpoints.users.vpn.disable(userId)),
  getVPNConfig: (userId: string) => api.get(endpoints.vpn.config(userId)),
  updateVPNConfig: (userId: string, config: any) => api.post(endpoints.vpn.config(userId), config),
  
  // Admin
  getRegistrations: () => api.get(endpoints.admin.registrations.list),
  approveRegistration: (id: string) => api.post(endpoints.admin.registrations.approve(id)),
  rejectRegistration: (id: string) => api.post(endpoints.admin.registrations.reject(id)),
  
  getInvites: () => api.get(endpoints.admin.invites.list),
  createInvite: (data: { email: string; expiresHours: number }) =>
    api.post(endpoints.admin.invites.create, data),
  deleteInvite: (token: string) => api.delete(endpoints.admin.invites.delete(token)),
  
  restartAuthelia: () => api.post(endpoints.admin.authelia.restart),
  
  // TeamSpeak
  getTeamSpeakUsers: () => api.get(endpoints.teamspeak.users.list),
  createTeamSpeakUser: (data: any) => api.post(endpoints.teamspeak.users.create, data),
  updateTeamSpeakUser: (id: string, data: any) => api.put(endpoints.teamspeak.users.update(id), data),
  deleteTeamSpeakUser: (id: string) => api.delete(endpoints.teamspeak.users.delete(id)),
  
  getTeamSpeakChannels: () => api.get(endpoints.teamspeak.channels.list),
  createTeamSpeakChannel: (data: any) => api.post(endpoints.teamspeak.channels.create, data),
  
  // Health
  healthCheck: () => api.get(endpoints.health),
}

export default api