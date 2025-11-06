import Image from "next/image";

export const Footer = () => {
  return (
    <footer className="flex flex-col gap-10 py-20 md:gap-24">
      <div className="flex flex-col justify-between gap-8 md:flex-row">
        <div className="flex flex-1 items-center justify-between gap-12 md:grow-2 md:flex-col md:items-start">
          <Image
            src="/logo.svg"
            alt="ARX"
            width={104}
            height={32}
            className="h-6 w-auto md:h-auto"
          />
          <Image
            src="/images/qr.svg"
            alt="ARX"
            width={104}
            height={32}
            className="hidden h-50 w-50 md:block"
          />
          <span className="text-content-100 block text-xs md:hidden">
            © 2025 All rights reserved.
          </span>
        </div>
        <div className="flex flex-1 grow-3 flex-col gap-15">
          <div className="flex justify-between gap-8">
            <div className="flex flex-1 flex-col gap-5">
              <span className="text-content-100 text-base md:text-lg">
                Resources
              </span>
              {["GitHub", "GitBook", "Etherscan", "CoinMarketCap"].map(
                (item) => (
                  <span
                    key={item}
                    className="text-content-70 hover:text-content-100 cursor-pointer text-base transition-all duration-300 md:text-lg"
                  >
                    {item}
                  </span>
                ),
              )}
            </div>
            <div className="flex flex-1 flex-col gap-5">
              <span className="text-content-100 text-base md:text-lg">
                Social networks
              </span>
              {["Telegram", "Facebook", "LinkedIn", "X.com"].map((item) => (
                <span
                  key={item}
                  className="text-content-70 hover:text-content-100 cursor-pointer text-base transition-all duration-300 md:text-lg"
                >
                  {item}
                </span>
              ))}
            </div>
          </div>
          <div>
            <span className="text-content-50 text-xs">
              Arx – private network for messaging, payments, and connectivity.
              Holding or using $ARX does not constitute an investment contract
              or a promise of future value. $ARX is a utility token used for
              governance, staking, and network operations.
            </span>
          </div>
        </div>
      </div>
      <div className="flex justify-between gap-8">
        <div className="hidden flex-1 grow-2 md:flex">
          <span className="text-content-100 text-xs">
            © 2025 All rights reserved.
          </span>
        </div>
        <div className="flex flex-1 justify-between gap-2 md:grow-3 md:justify-start md:gap-12">
          {[
            "Terms of Service",
            "KYC/AML Policy",
            "Privacy Policy",
            "Cookie Policy",
          ].map((item) => (
            <span
              key={item}
              className="text-content-70 hover:text-content-100 cursor-pointer text-xs underline transition-all duration-300"
            >
              {item}
            </span>
          ))}
        </div>
      </div>
    </footer>
  );
};
