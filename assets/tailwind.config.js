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
  },
  plugins: [require("daisyui")],
};
