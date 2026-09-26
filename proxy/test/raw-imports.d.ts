// Vite's `?raw` suffix imports a file's text; used to check a module's imports.
declare module '*?raw' {
  const text: string;
  export default text;
}
