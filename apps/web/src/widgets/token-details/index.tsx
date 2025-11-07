import { RecentTransaction } from "../recent-transactions";
import { TokenInfo } from "../token-info";

export const TokenDetails = () => {
  return (
    <div className="flex flex-col items-center gap-10 md:gap-20">
      <div className="flex flex-col items-center gap-6">
        <h1 className="flex items-center gap-2 text-center text-[32px] leading-[105%] font-semibold md:text-[60px]">
          Token details & activity
        </h1>
        <p className="text-content-70 max-w-md text-center text-lg md:text-xl">
          Learn more about the ARX token — its role in the Arx Network and your
          recent activity.{" "}
        </p>
      </div>
      <div className="grid w-full grid-cols-1 gap-5 md:grid-cols-2">
        <TokenInfo />
        <RecentTransaction />
      </div>
    </div>
  );
};
