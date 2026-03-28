import { readFile, writeFile } from "node:fs/promises"
import { A3, A3ParseError } from "./a3"

/**
 * Read an A3 JSON file from disk and return a validated A3 instance.
 * @param path Absolute or relative path to a .json file.
 */
export async function readJSON(path: string): Promise<A3> {
  let text: string
  try {
    text = await readFile(path, "utf-8")
  } catch (e) {
    throw new A3ParseError(`Cannot read file: ${path}`, { cause: e })
  }
  return A3.fromJSONText(text)
}

/**
 * Write an A3 instance to a JSON file.
 * @param a3    The A3 instance to serialize.
 * @param path  Absolute or relative path to write.
 * @param indent Number of spaces for indentation (default 2).
 */
export async function writeJSON(a3: A3, path: string, indent = 2): Promise<void> {
  const text = a3.toJSONString(indent)
  try {
    await writeFile(path, text, "utf-8")
  } catch (e) {
    throw new A3ParseError(`Cannot write file: ${path}`, { cause: e })
  }
}
