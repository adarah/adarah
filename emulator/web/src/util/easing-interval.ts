export function easingInterval(fn: () => void, delay: number) {
  let id: ReturnType<typeof setTimeout>;
  let d = delay;
  const repeat = () => {
    fn();
    d = Math.floor(d / 2);
    id = setTimeout(repeat, d);
  }
  id = setTimeout(repeat, delay);
  return () => clearTimeout(id)
}