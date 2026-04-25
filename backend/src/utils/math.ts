export function average(values: number[]): number {
  if (!values.length) {
    return 0;
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

export function roundCurrency(value: number): number {
  return Number(value.toFixed(2));
}

export function daysToText(days: number): string {
  if (days <= 0) {
    return "Now";
  }
  if (days < 14) {
    return `${Math.round(days)} days`;
  }
  return `${Math.round(days / 7)} weeks`;
}
