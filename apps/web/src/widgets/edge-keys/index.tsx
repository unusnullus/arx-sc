export const EdgeKeys = () => {
  return (
    <div className="flex flex-col items-center gap-25 py-20">
      <div className="flex flex-col items-center gap-8">
        <div className="mb-8 flex-shrink-0">
          <video
            src="/videos/lock.mp4"
            autoPlay
            loop
            muted
            playsInline
            className="size-40"
          />
        </div>
        <div className="flex flex-col items-center">
          <h1 className="flex items-center gap-2 text-[60px] leading-[105%] font-semibold">
            Edge keys
          </h1>
          <h1 className="text-content-50 text-[60px] leading-[105%] font-semibold">
            Off-chain messages.
          </h1>
          <h1 className="text-content-50 text-[60px] leading-[105%] font-semibold">
            On-chain incentives.
          </h1>
        </div>
        <p className="text-content-70 text-center text-lg">
          Your identity is EOA (ETH) + Signal identity; you sign once and keep
          keys local.
          <br /> Messages stay off-chain. The chain coordinates trust, staking,
          rewards, and governance.
        </p>
      </div>
    </div>
  );
};
