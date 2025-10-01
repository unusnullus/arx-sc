import Roadmap from "@/components/Roadmap";

export default function Home() {
  return (
    <div className="min-h-screen">
      <section className="py-20 text-center space-y-6">
        <h1 className="text-4xl md:text-6xl font-bold">ARX Network</h1>
        <p className="text-neutral-400 max-w-2xl mx-auto">
          Private, resilient messenger and network. Join governance with $ARX.
        </p>
        <div className="flex gap-3 justify-center">
          <a
            className="rounded bg-cyan-500 text-black px-5 py-3"
            href="#download"
          >
            Download
          </a>
          <a
            className="rounded bg-neutral-900 text-white px-5 py-3"
            href="/buy"
          >
            Buy $ARX — Join Governance
          </a>
          <a
            className="rounded bg-neutral-900 text-white px-5 py-3"
            href="/arxnet"
          >
            Run a Node
          </a>
        </div>
      </section>
      <section className="py-10">
        <Roadmap />
      </section>
    </div>
  );
}
