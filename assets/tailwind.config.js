const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  theme: {
    fontFamily: {
      sans: ["Nunito Sans", ...defaultTheme.fontFamily.sans],
    },
    maxHeight: {
      0: "0",
      "1/4": "25%",
      "1/2": "50%",
      "3/4": "75%",
    },
    width: {
      "fill-available":
        "-moz-available" /* WebKit-based browsers will ignore this. */,
      "fill-available":
        "-webkit-fill-available" /* Mozilla-based browsers will ignore this. */,
      "fill-available": "fill-available",
    },
  },
  plugins: [require("daisyui")],
};
