"use client";

import { useState } from "react";

/**
 * Today's entries per hour (A2). One series → one hue (brand-strong, which clears 3:1
 * on the card), no legend (the title names it). Bars ≤ 24 px with rounded tops on one
 * baseline, a 2 px gap, recessive gridlines, the peak labelled directly, a tooltip per
 * bar, and the same numbers as a table for screen readers.
 */
export function HourlyChart({
  counts,
  from = 5,
  to = 22,
}: {
  counts: number[];
  from?: number;
  to?: number;
}) {
  const hours = Array.from({ length: to - from + 1 }, (_, i) => from + i);
  const values = hours.map((h) => counts[h] ?? 0);
  const max = Math.max(4, ...values);
  const step = max <= 8 ? 2 : max <= 20 ? 5 : Math.ceil(max / 4 / 10) * 10;
  const top = Math.ceil(max / step) * step;
  const peak = values.indexOf(Math.max(...values));
  const [hover, setHover] = useState<number | null>(null);
  const label = (h: number) => `${String(h).padStart(2, "0")}:00`;

  return (
    <figure>
      <div
        className="relative flex h-48 gap-2 pl-8"
        role="img"
        aria-label="Entries per hour today"
      >
        {/* gridlines and axis labels */}
        {Array.from({ length: top / step + 1 }, (_, i) => i * step).map((v) => (
          <div
            key={v}
            className="pointer-events-none absolute right-0 left-8 border-t border-border"
            style={{ bottom: `${(v / top) * 100}%` }}
          >
            <span className="absolute -top-2 -left-8 w-6 text-right text-caption text-text-muted">
              {v}
            </span>
          </div>
        ))}
        {hours.map((h, i) => {
          const v = values[i];
          return (
            <div
              key={h}
              className="relative flex flex-1 items-end justify-center"
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
              onFocus={() => setHover(i)}
              onBlur={() => setHover(null)}
              tabIndex={0}
              aria-label={`${label(h)}: ${v} ${v === 1 ? "entry" : "entries"}`}
            >
              <div
                className={`w-full max-w-6 rounded-t-[4px] ${hover === i ? "bg-ink" : "bg-brand-strong"}`}
                style={{ height: `${(v / top) * 100}%`, minHeight: v ? 2 : 0 }}
              />
              {i === peak && v > 0 && hover === null && (
                <span
                  className="absolute text-caption font-semibold text-ink"
                  style={{ bottom: `calc(${(v / top) * 100}% + 4px)` }}
                >
                  {v}
                </span>
              )}
              {hover === i && (
                <span
                  className="absolute z-10 rounded-full bg-ink px-2.5 py-1 text-caption whitespace-nowrap text-surface"
                  style={{ bottom: `calc(${(v / top) * 100}% + 6px)` }}
                >
                  {label(h)} · {v}
                </span>
              )}
            </div>
          );
        })}
      </div>
      <div className="mt-2 flex gap-2 pl-8" aria-hidden>
        {hours.map((h) => (
          <span
            key={h}
            className="flex-1 text-center text-caption text-text-muted"
          >
            {h % 2 === 0 ? h : ""}
          </span>
        ))}
      </div>
      <table className="sr-only">
        <caption>Entries per hour today</caption>
        <tbody>
          {hours.map((h, i) => (
            <tr key={h}>
              <th scope="row">{label(h)}</th>
              <td>{values[i]}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}
