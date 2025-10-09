// src/components/HeatmapCalendar.jsx
import * as d3 from "d3";
import { useEffect, useRef } from "react";

export default function HeatmapCalendar({ data, kpi, month, year }) {
  const ref = useRef();

  useEffect(() => {
    if (!data || data.length === 0) return;

    const width = 800;
    const cellSize = 20;
    const height = 180;
    const svg = d3.select(ref.current);
    svg.selectAll("*").remove();

    const monthData = data.filter(d => {
      const dt = new Date(d.date);
      return dt.getMonth() === month && dt.getFullYear() === year;
    });

    const colorScale = d3
      .scaleSequential()
      .domain(d3.extent(monthData, d => d[kpi]))
      .interpolator(d3.interpolateYlOrRd);

    const grouped = d3.group(monthData, d => d.date);

    const days = Array.from(grouped, ([date, val]) => ({
      date: new Date(date),
      value: val[0][kpi],
    }));

    const dayOfWeek = d3.scaleBand().domain(d3.range(7)).range([0, 7 * cellSize]);
    const weekOfMonth = d3.scaleBand().domain(d3.range(6)).range([0, 6 * cellSize]);

    svg
      .attr("width", width)
      .attr("height", height)
      .selectAll("rect")
      .data(days)
      .join("rect")
      .attr("x", d => d3.timeWeek.count(d3.timeMonth(d.date), d.date) * cellSize)
      .attr("y", d => d.date.getDay() * cellSize)
      .attr("width", cellSize - 2)
      .attr("height", cellSize - 2)
      .attr("fill", d => colorScale(d.value));

    svg
      .append("text")
      .attr("x", 0)
      .attr("y", 15)
      .text(`${d3.timeFormat("%B %Y")(new Date(year, month, 1))}`)
      .style("font-weight", "bold");
  }, [data, kpi, month, year]);

  return <svg ref={ref}></svg>;
}