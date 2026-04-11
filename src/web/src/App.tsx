import { Routes, Route, Navigate } from 'react-router-dom';
import { RequestListPage } from './pages/RequestListPage';
import { RequestDetailPage } from './pages/RequestDetailPage';
import { NewRequestPage } from './pages/NewRequestPage';

function App() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px', fontFamily: 'system-ui, sans-serif' }}>
      <Routes>
        <Route path="/" element={<RequestListPage />} />
        <Route path="/requests/:id" element={<RequestDetailPage />} />
        <Route path="/new" element={<NewRequestPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </div>
  );
}

export default App;
