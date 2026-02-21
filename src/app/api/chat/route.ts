import { MOCK_RESPONSES, KEYWORD_PRIORITIES } from "@/lib/mockData";

export async function POST(request: Request) {
  try {
    const { messages, model } = await request.json();
    const lastMessage = messages[messages.length - 1]?.content?.toLowerCase() ?? "";

    let responseText = MOCK_RESPONSES.default;
    for (const keyword of KEYWORD_PRIORITIES) {
      if (lastMessage.includes(keyword)) {
        responseText = MOCK_RESPONSES[keyword];
        break;
      }
    }

    responseText = `*Using ${model ?? "claude-sonnet"}*\n\n${responseText}`;

    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const tokens = responseText.split(" ");
        for (const token of tokens) {
          controller.enqueue(encoder.encode(token + " "));
          await new Promise((resolve) => setTimeout(resolve, 25));
        }
        controller.close();
      },
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-cache",
      },
    });
  } catch {
    return new Response("Internal server error", { status: 500 });
  }
}
