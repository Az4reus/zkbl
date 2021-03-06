 defmodule Zkbl.Parser do
  @type sexp :: [String.t]

  @doc """
  Pipeline function you can pass a raw string of lisp, and have appropriately nested
  Tokens in lists come out.

  ## Examples

    iex> Zkbl.Parser.parse_lisp "(losses (any (alliance 'White Legion.')))"
    {:ok, ["losses", ["any", ["alliance", "'White Legion.'"]]]}
  """
  def parse_lisp(string) do
    String.replace(string, ")", " ) ")
    |> String.replace("(", " ( ")
    |> String.split(" ")
    |> Enum.filter(&(&1 != ""))
    |> Zkbl.Parser.make_sexp
  end

  @doc """
  Takes a flat list of tokens, returns nested list that represent order
  and depth of the input lisp expression.

  ## Examples

    iex> Zkbl.Parser.make_sexp(["(", "foo", ")"])
    {:ok, ["foo"]}

    iex> Zkbl.Parser.make_sexp(["(", "foo", "(", "bar", ")", ")"])
    {:ok, ["foo", ["bar"]]}

  """
  @spec make_sexp([String.t]) :: {atom, sexp} | {atom, String.t}
  def make_sexp(["(" | tail]) do
    {result, _} = make_sexp_acc(tail, [])
    result = reconstruct_strings!(result)
    {:ok, result}
  end

  def make_sexp([_ | _]) do
    {:error, "Not a Lisp Expression. Must start with an open parens: '('"}
  end

  def make_sexp(_) do
    {:error, "Must pass a list in order to actually parse lisp."}
  end

  ##
  # Internal worker function.

  @spec make_sexp_acc([String.t], [String.t]) :: {[String.t], [String.t]}
  defp make_sexp_acc(["("| tail], acc) do
    {inner, leftovers} = make_sexp_acc(tail, [])
    make_sexp_acc(leftovers, acc ++ [inner])
  end

  defp make_sexp_acc([")"|tail], acc) do
    {acc, tail}
  end

  defp make_sexp_acc([head | tail], acc) do
    make_sexp_acc(tail, acc ++ [head])
  end


  @doc """
  This function reconstructs the strings between '' or "" that got broken during
  my naive tokenification.

    ## Examples
    iex> Zkbl.Parser.reconstruct_strings! ["'Foo", "Bar'"]
    ["'Foo Bar'"]

    iex> Zkbl.Parser.reconstruct_strings! ["'Terrible", "Terrible", "Damage'"]
    ["'Terrible Terrible Damage'"]
  """
  @spec reconstruct_strings!([String.t]) :: {atom, [String.t]}
  def reconstruct_strings!(ast) do
    reconstruct_strings_acc(ast, [])
  end

  ##
  # Internal worker function, for nicer API compared to actual workings.

  defp reconstruct_strings_acc([], acc) do
    acc
  end

  defp reconstruct_strings_acc([head | tail], acc) when is_list(head) do
    reconstruct_strings_acc(tail, acc ++ [reconstruct_strings_acc(head, [])])
  end

  defp reconstruct_strings_acc([head | tail], acc) do
    case String.starts_with?(head, "'") do
      false -> reconstruct_strings_acc(tail, acc ++ [head])
      true  ->
        {reconstructed, leftovers} = accumulate_string!([head | tail], [])
        reconstruct_strings_acc(leftovers, acc ++ [reconstructed])
    end
  end

  ##
  # Collects a string until it hits a closing apostrophe, because really, using
  # Enum.take_while would be far too easy. (And it would not actually
  # collect the part with the closing apostrophe.)

  defp accumulate_string!([], _) do
    raise "Missing quotation mark in expression"
  end

  defp accumulate_string!([head | tail], acc) do
    cond do
      String.ends_with?(head, "'") ->
        joined = acc ++ [head] |> Enum.join(" ")
        {joined, tail}

      true ->
        accumulate_string!(tail, acc ++ [head])
    end
  end
end