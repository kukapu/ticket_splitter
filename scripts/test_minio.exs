#!/usr/bin/env elixir

# Script de diagnóstico para MinIO
# Ejecuta: elixir scripts/test_minio.exs

Mix.install([
  {:ex_aws, "~> 2.5"},
  {:ex_aws_s3, "~> 2.5"},
  {:hackney, "~> 1.20"}
])

IO.puts("\n🔍 Diagnóstico de Configuración MinIO\n")

# Leer variables de entorno
scheme = System.get_env("MINIO_SCHEME", "https") |> String.trim_trailing("://")
host = System.get_env("MINIO_HOST", "s3.kukapu.dev")
port = System.get_env("MINIO_PORT", "443") |> String.to_integer()
region = System.get_env("MINIO_REGION", "us-east-1")
bucket = System.get_env("MINIO_BUCKET", "ticket-splitter")
access_key = System.get_env("MINIO_ACCESS_KEY")
secret_key = System.get_env("MINIO_SECRET_KEY")

IO.puts("📋 Configuración:")
IO.puts("  Scheme: #{scheme}")
IO.puts("  Host: #{host}")
IO.puts("  Port: #{port}")
IO.puts("  Region: #{region}")
IO.puts("  Bucket: #{bucket}")
IO.puts("  Access Key: #{if access_key, do: "✅ Configurado (#{String.slice(access_key, -4..-1)})", else: "❌ NO configurado"}")
IO.puts("  Secret Key: #{if secret_key, do: "✅ Configurado (#{String.slice(secret_key, -4..-1)})", else: "❌ NO configurado"}")

if !access_key || !secret_key do
  IO.puts("\n❌ ERROR: MINIO_ACCESS_KEY y MINIO_SECRET_KEY deben estar configurados")
  System.halt(1)
end

# Configurar ExAws
Application.put_env(:ex_aws, :access_key_id, access_key)
Application.put_env(:ex_aws, :secret_access_key, secret_key)
Application.put_env(:ex_aws, :s3, [
  scheme: scheme,
  host: host,
  port: port,
  region: region
])

IO.puts("\n🧪 Probando conexión a MinIO...\n")

# Test 1: Listar buckets
IO.puts("1️⃣ Listando buckets...")
case ExAws.S3.list_buckets() |> ExAws.request() do
  {:ok, %{body: %{buckets: buckets}}} ->
    IO.puts("   ✅ Conexión exitosa!")
    IO.puts("   📦 Buckets encontrados: #{Enum.map(buckets, & &1.name) |> Enum.join(", ")}")

    if Enum.any?(buckets, &(&1.name == bucket)) do
      IO.puts("   ✅ Bucket '#{bucket}' existe")
    else
      IO.puts("   ⚠️  Bucket '#{bucket}' NO existe. Créalo en la consola de MinIO.")
    end

  {:error, error} ->
    IO.puts("   ❌ Error: #{inspect(error)}")
    System.halt(1)
end

# Test 2: Subir archivo de prueba
IO.puts("\n2️⃣ Subiendo archivo de prueba...")
test_content = "Test file - #{DateTime.utc_now()}"
test_key = "test/diagnostic-#{:rand.uniform(10000)}.txt"

case ExAws.S3.put_object(bucket, test_key, test_content, [
  {:content_type, "text/plain"},
  {:acl, :public_read}
]) |> ExAws.request() do
  {:ok, _} ->
    IO.puts("   ✅ Archivo subido exitosamente: #{test_key}")

    # Test 3: Eliminar archivo de prueba
    IO.puts("\n3️⃣ Eliminando archivo de prueba...")
    case ExAws.S3.delete_object(bucket, test_key) |> ExAws.request() do
      {:ok, _} ->
        IO.puts("   ✅ Archivo eliminado exitosamente")
      {:error, error} ->
        IO.puts("   ⚠️  Error al eliminar: #{inspect(error)}")
    end

  {:error, error} ->
    IO.puts("   ❌ Error al subir: #{inspect(error)}")

    case error do
      {:http_error, 403, %{body: body}} ->
        IO.puts("\n🔍 Análisis del error 403:")
        if String.contains?(body, "SignatureDoesNotMatch") do
          IO.puts("   ❌ Las credenciales son incorrectas o la firma no coincide")
          IO.puts("   💡 Verifica:")
          IO.puts("      1. MINIO_ACCESS_KEY y MINIO_SECRET_KEY son correctos")
          IO.puts("      2. No hay espacios extra al inicio o final")
          IO.puts("      3. La región es correcta (prueba con 'us-east-1')")
        end

      _ ->
        IO.puts("   Error completo: #{inspect(error)}")
    end

    System.halt(1)
end

IO.puts("\n✅ ¡Todos los tests pasaron! La configuración es correcta.\n")
