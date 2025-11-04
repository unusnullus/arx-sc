export const formatPrice = ({
  price,
  currency = "USD",
  minimumFractionDigits,
  maximumFractionDigits = 2,
}: {
  price: number;
  currency?: string;
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
}) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    minimumFractionDigits,
    maximumFractionDigits,
  }).format(price);
};

export const formatNumber = ({
  number,
  minimumFractionDigits,
  maximumFractionDigits = 2,
}: {
  number: number;
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
}) => {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits,
    maximumFractionDigits,
  }).format(number);
};
