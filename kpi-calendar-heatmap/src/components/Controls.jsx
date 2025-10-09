// src/components/Controls.jsx
export default function Controls({ month, setMonth, year, setYear, kpi, setKpi, kpiList }) {
  return (
    <div className="flex gap-4 mb-4">
      <select value={month} onChange={e => setMonth(Number(e.target.value))}>
        {Array.from({ length: 12 }).map((_, i) => (
          <option key={i} value={i}>{new Date(0, i).toLocaleString("default", { month: "long" })}</option>
        ))}
      </select>
      <input type="number" value={year} onChange={e => setYear(Number(e.target.value))} />
      <select value={kpi} onChange={e => setKpi(e.target.value)}>
        {kpiList.map(k => <option key={k}>{k}</option>)}
      </select>
    </div>
  );
}