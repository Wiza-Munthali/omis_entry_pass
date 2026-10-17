import { createCn } from "cn/config";

/**
 * Class merging that knows the design system's custom scales. Without this, the
 * merger reads `text-body` (a font size) as a colour and drops `text-brand` from
 * "text-brand text-body". Import cn from here, never from "cn" directly.
 */
export const cn = createCn({
  extend: {
    classGroups: {
      "font-size": [{ text: ["display", "title", "body", "label", "caption"] }],
      rounded: [{ rounded: ["card", "sheet"] }],
    },
  },
});
