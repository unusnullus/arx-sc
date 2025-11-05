export default function LoginPage() {
  async function handle(data: FormData) {
    "use server";
    const password = data.get("password");
    if (password === process.env.PASSWORD) {
      return {
        "Set-Cookie": `auth=1; Path=/; HttpOnly; Max-Age=86400`,
      };
    }
    throw new Error("Wrong password");
  }

  return (
    <form
      action={
        handle as unknown as
          | string
          | ((formData: FormData) => void | Promise<void>)
      }
    >
      <input name="password" type="password" />
      <button type="submit">Enter</button>
    </form>
  );
}
