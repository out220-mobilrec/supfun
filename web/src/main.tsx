import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import './index.css';
import { AuthProvider } from './store/AuthContext';
import { SocketProvider } from './store/SocketContext';
import { I18nProvider } from './i18n';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <I18nProvider>
          <SocketProvider>
            <App />
          </SocketProvider>
        </I18nProvider>
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>,
);