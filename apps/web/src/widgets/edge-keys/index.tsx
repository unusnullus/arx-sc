export const EdgeKeys = () => {
  return (
    <div className="flex flex-col items-center py-20 gap-25">
      <div className="flex flex-col items-center gap-8">
        <div className="flex-shrink-0 mb-8">
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
          <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
            Edge keys
          </h1>
          <h1 className="text-[60px] font-semibold text-content-50 leading-[105%]">
            Off-chain messages.
          </h1>
          <h1 className="text-[60px] font-semibold text-content-50 leading-[105%]">
            On-chain incentives.
          </h1>
        </div>
        <p className="text-content-70 text-lg text-center">
          Your identity is EOA (ETH) + Signal identity; you sign once and keep
          keys local.
          <br /> Messages stay off-chain. The chain coordinates trust, staking,
          rewards, and governance.
        </p>
      </div>
    </div>
  );
};
