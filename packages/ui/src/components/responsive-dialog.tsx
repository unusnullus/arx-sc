"use client";

import * as React from "react";

import { useMediaQuery } from "../hooks/use-media-query";
import { Button } from "./button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "./dialog";
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from "./drawer";

export const ResponsiveDialog = ({
  children,
  title,
  description,
  closeButtonText,
  open,
  onOpenChange,
}: {
  children: React.ReactNode;
  title: string;
  description: string;
  closeButtonText: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) => {
  const isDesktop = useMediaQuery("(min-width: 768px)");

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="bg-content-grey border-white-10 rounded-[20px] sm:max-w-[500px] md:rounded-4xl">
          <DialogHeader>
            {title && (
              <DialogTitle className="text-content-100 text-lg font-semibold">
                {title}
              </DialogTitle>
            )}
            {description && (
              <DialogDescription className="text-content-70 text-sm">
                {description}
              </DialogDescription>
            )}
          </DialogHeader>
          {children}
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="bg-content-grey border-white-10 rounded-[20px]  md:rounded-4xl px-4">
        <DrawerHeader className="text-left">
          {title && (
            <DrawerTitle className="text-content-100 text-lg font-semibold">
              {title}
            </DrawerTitle>
          )}
          {description && (
            <DrawerDescription className="text-content-70 text-sm">
              {description}
            </DrawerDescription>
          )}
        </DrawerHeader>
        {children}
        <DrawerFooter className="pt-2">
          <DrawerClose asChild>
            <Button
              variant="outline"
              className="text-content-100 border-white-10 hover:bg-white-10 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
            >
              {closeButtonText}
            </Button>
          </DrawerClose>
        </DrawerFooter>
      </DrawerContent>
    </Drawer>
  );
};
