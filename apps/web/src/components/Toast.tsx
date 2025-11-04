// "use client";
// import {
//   createContext,
//   useCallback,
//   useContext,
//   useMemo,
//   useRef,
//   useState,
// } from "react";

// type ToastVariant = "info" | "success" | "error";
// type ToastItem = {
//   id: number;
//   title: string;
//   description?: string;
//   variant: ToastVariant;
// };

// const ToastCtx = createContext<{
//   push: (t: Omit<ToastItem, "id">) => void;
// } | null>(null);

// export function useToast() {
//   const ctx = useContext(ToastCtx);
//   if (!ctx) throw new Error("useToast must be used within ToastProvider");
//   return ctx;
// }

// export default function ToastProvider({
//   children,
// }: {
//   children: React.ReactNode;
// }) {
//   const [items, setItems] = useState<ToastItem[]>([]);
//   const idRef = useRef(1);
//   const push = useCallback((t: Omit<ToastItem, "id">) => {
//     const id = idRef.current++;
//     const item: ToastItem = { id, ...t };
//     setItems((arr) => [...arr, item]);
//     setTimeout(() => setItems((arr) => arr.filter((x) => x.id !== id)), 5000);
//   }, []);

//   const value = useMemo(() => ({ push }), [push]);

//   return (
//     <ToastCtx.Provider value={value}>
//       {children}
//       <div className="fixed top-4 right-4 z-[100] flex flex-col gap-2">
//         {items.map((t) => (
//           <div
//             key={t.id}
//             className="min-w-[260px] max-w-[380px] rounded-md border px-4 py-3 shadow-lg"
//             style={{
//               background: "rgba(10,11,15,0.8)",
//               backdropFilter: "blur(8px)",
//               borderColor:
//                 t.variant === "success"
//                   ? "rgba(34,197,94,0.4)"
//                   : t.variant === "error"
//                     ? "rgba(239,68,68,0.4)"
//                     : "rgba(120,88,255,0.4)",
//             }}
//           >
//             <div className="text-sm font-semibold flex items-center gap-2">
//               <span
//                 className="inline-block h-2.5 w-2.5 rounded-full"
//                 style={{
//                   backgroundColor:
//                     t.variant === "success"
//                       ? "#22c55e"
//                       : t.variant === "error"
//                         ? "#ef4444"
//                         : "#7858FF",
//                 }}
//               />
//               {t.title}
//             </div>
//             {t.description && (
//               <div className="mt-1 text-xs text-neutral-400">
//                 {t.description}
//               </div>
//             )}
//           </div>
//         ))}
//       </div>
//     </ToastCtx.Provider>
//   );
// }
