const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  theme: {
    fontFamily: {
      sans: ["Nunito Sans", ...defaultTheme.fontFamily.sans],
    },
  },
  plugins: [require("daisyui")],
};
