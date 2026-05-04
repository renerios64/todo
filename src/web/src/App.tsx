import { Routes, Route, Navigate, Link } from 'react-router-dom';
import { RequestListPage } from './pages/RequestListPage';
import { RequestDetailPage } from './pages/RequestDetailPage';
import { NewRequestPage } from './pages/NewRequestPage';

function App() {
  return (
    <>
      <header className="app-header">
        <Link to="/" className="logo">
          Service <span className="logo-accent">Tracker</span>
        </Link>
      </header>
      <main style={{ flex: 1 }}>
        <Routes>
          <Route path="/" element={<RequestListPage />} />
          <Route path="/requests/:id" element={<RequestDetailPage />} />
          <Route path="/new" element={<NewRequestPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </>
  );
}

export default App;
