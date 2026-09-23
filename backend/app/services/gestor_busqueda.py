"""Lógica de negocio para búsqueda y filtrado."""


class GestorBusqueda:
    def buscar_por_palabra_clave(self, publicaciones, palabra: str):
        """Devuelve solo las publicaciones que coinciden con la palabra clave."""
        if not palabra:
            return list(publicaciones or [])

        palabra = palabra.strip().lower()
        resultados = []
        for publicacion in publicaciones or []:
            texto = " ".join(
                [
                    str(getattr(publicacion, "titulo", "")),
                    str(getattr(publicacion, "descripcion", "")),
                ]
            ).lower()
            if palabra in texto:
                resultados.append(publicacion)
        return resultados

    def filtrar_por_categoria(self, publicaciones, categoria_id: int):
        """Filtra publicaciones por el identificador de categoría."""
        if categoria_id is None:
            return list(publicaciones or [])

        return [
            publicacion
            for publicacion in publicaciones or []
            if getattr(publicacion, "categoria_id", None) == categoria_id
        ]
