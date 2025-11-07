import { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = "https://www.arxnet.io";

  return [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: "daily",
      priority: 1,
    },
    {
      url: `${baseUrl}/buy`,
      lastModified: new Date(),
      changeFrequency: "daily",
      priority: 0.9,
    },
  ];
}
