import {
  Button,
  Card,
  CardContent,
  Separator,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@arx/ui/components";
import { format, setMinutes } from "date-fns";
import { ExternalLink } from "lucide-react";
import Link from "next/link";
import Image from "next/image";

export const TokenInfo = () => {
  return (
    <Card className="bg-white-7 w-full rounded-4xl">
      <CardContent className="space-y-6">
        <div className="flex flex-col justify-between sm:flex-row sm:items-center">
          <div className="flex items-center gap-2">
            <span className="text-content-100 font-semibold sm:text-lg lg:text-xl">
              Token Info
            </span>
            <Tooltip useTouch>
              <TooltipTrigger asChild>
                <Link href="/" target="_blank" rel="noopener noreferrer">
                  <Button variant="ghost" size="icon">
                    <ExternalLink className="text-base-secondary size-4" />
                  </Button>
                </Link>
              </TooltipTrigger>
              <TooltipContent>
                <p>Open token details</p>
              </TooltipContent>
            </Tooltip>
          </div>
          <p className="text-content-50 text-sm">
            Price as of{" "}
            {format(setMinutes(new Date(), 0), "HH:mm, dd MMM yyyy")}
          </p>
        </div>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Image
              src={"/tokens/arx-2.svg"}
              alt="ARX"
              width={36}
              height={36}
              className="size-6 rotate-180 sm:size-7 md:size-8 lg:size-14"
            />
            <div className="flex flex-col gap-1">
              <span className="text-content-100 text-base font-semibold sm:text-xl">
                ARX
              </span>
              <span className="text-content-70 text-base">ERC-20</span>
            </div>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-content-100 text-base font-semibold sm:text-xl">
              $0.9038 / token
            </span>
            <span className="text-content-70 text-right text-sm">
              Current market rate
            </span>
          </div>
        </div>
        <Separator />
        <p className="text-content-70 text-base leading-[150%]">
          A native token securing ArxNet — stake, govern, and earn rewards for
          powering private communication and decentralized infrastructure.{" "}
          <br />
          Tail emission declines annually for 10 years and mints only to the
          Rewards Pool; governance can tighten further
        </p>
      </CardContent>
    </Card>
  );
};
