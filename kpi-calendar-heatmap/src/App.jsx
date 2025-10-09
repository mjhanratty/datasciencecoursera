import React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import HeatmapCalendar from './components/HeatmapCalendar';
import Controls from './components/Controls';
import './index.css';

// Create a client
const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <div className="min-h-screen bg-gray-50">
        <div className="container mx-auto px-4 py-8">
          <header className="mb-8">
            <h1 className="text-4xl font-bold text-gray-900 text-center">
              KPI Calendar Heatmap
            </h1>
            <p className="text-gray-600 text-center mt-2">
              Visualize your key performance indicators over time
            </p>
          </header>
          
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <div className="lg:col-span-1">
              <Controls />
            </div>
            <div className="lg:col-span-3">
              <HeatmapCalendar />
            </div>
          </div>
        </div>
      </div>
    </QueryClientProvider>
  );
}

export default App;